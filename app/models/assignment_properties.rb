# Internal model used to link assignment attributes with the assignment STI model
class AssignmentProperties < ApplicationRecord
  belongs_to :assignment, inverse_of: :assignment_properties, dependent: :destroy, foreign_key: :assessment_id
  validates_presence_of :assignment

  validates_numericality_of :group_min, only_integer: true, greater_than: 0
  validates_numericality_of :group_max, only_integer: true, greater_than: 0

  validates :repository_folder, presence: true, exclusion: { in: Repository.get_class.reserved_locations }
  validate :repository_folder_unchanged, on: :update
  validates_presence_of :group_min
  validates_presence_of :group_max

  # "validates_presence_of" for boolean values.
  validates_inclusion_of :allow_web_submits, in: [true, false]
  validates_inclusion_of :vcs_submit, in: [true, false]
  validates_inclusion_of :display_grader_names_to_students, in: [true, false]
  validates_inclusion_of :display_median_to_students, in: [true, false]
  validates_inclusion_of :has_peer_review, in: [true, false]
  validates_inclusion_of :assign_graders_to_criteria, in: [true, false]
  validates_inclusion_of :student_form_groups, in: [true, false]
  validates_inclusion_of :group_name_autogenerated, in: [true, false]
  validates_inclusion_of :group_name_displayed, in: [true, false]
  validates_inclusion_of :invalid_override, in: [true, false]
  validates_inclusion_of :section_groups_only, in: [true, false]
  validates_inclusion_of :only_required_files, in: [true, false]
  validates_inclusion_of :allow_web_submits, in: [true, false]
  validates_inclusion_of :section_due_dates_type, in: [true, false]
  validates_inclusion_of :assign_graders_to_criteria, in: [true, false]
  validates_inclusion_of :unlimited_tokens, in: [true, false]
  validates_inclusion_of :non_regenerating_tokens, in: [true, false]

  validates_inclusion_of :enable_test, in: [true, false]
  validates_inclusion_of :enable_student_tests, in: [true, false], if: :enable_test
  validates_inclusion_of :non_regenerating_tokens, in: [true, false], if: :enable_student_tests
  validates_inclusion_of :unlimited_tokens, in: [true, false], if: :enable_student_tests
  validates_presence_of :token_start_date, if: :enable_student_tests
  with_options if: -> { :enable_student_tests && !:unlimited_tokens } do |assignment|
    assignment.validates :tokens_per_period,
                         presence: true,
                         numericality: { only_integer: true,
                                         greater_than_or_equal_to: 0 }
  end
  with_options if: -> { !:non_regenerating_tokens && :enable_student_tests && !:unlimited_tokens } do |assignment|
    assignment.validates :token_period,
                         presence: true,
                         numericality: { greater_than: 0 }
  end

  validates_inclusion_of :scanned_exam, in: [true, false]

  validate :minimum_number_of_groups

  attribute :duration, :duration
  validates :duration, numericality: { greater_than: 0 }, allow_nil: false, if: :is_timed
  validates_presence_of :start_time, if: :is_timed
  validate :start_before_due, if: :is_timed
  validate :not_timed_and_scanned

  STARTER_FILE_TYPES = %w[simple sections shuffle group].freeze

  validates_inclusion_of :starter_file_type, in: STARTER_FILE_TYPES

  DURATION_PARTS = [:hours, :minutes].freeze

  # Update the repository permissions file if the vcs_submit
  # attribute was changed after a save.
  def update_permissions_if_vcs_changed
    return unless saved_change_to_vcs_submit?
    Repository.get_class.update_permissions
  end

  # Return the duration attribute for this assignment as a hash
  # with keys from +DURATION_PARTS+.
  #
  # For example:
  #
  # self.duration  # 10.hours and 4.minutes
  # self.duration_parts # {hours: 10, minutes: 4}
  def duration_parts
    AssignmentProperties.duration_parts(self.duration)
  end

  # Return +dur+ as a hash with keys from +DURATION_PARTS+.
  #
  # For example:
  #
  # dur  # 10.hours and 4.minutes
  # AssignmentProperties.duration_parts(dur) # {hours: 10, minutes: 4}
  def self.duration_parts(dur)
    dur = dur.to_i
    DURATION_PARTS.map do |part|
      amt = (dur / 1.send(part)).to_i
      dur -= amt.send(part)
      [part, amt]
    end.to_h
  end

  # Return the duration of this assignment plus any penalty periods
  def adjusted_duration
    duration + assignment.submission_rule.periods.pluck(:hours).sum.hours
  end

  private

  def minimum_number_of_groups
    return unless (group_max && group_min) && group_max < group_min
    errors.add(:group_max, 'must be greater than the minimum number of groups')
    false
  end

  def repository_folder_unchanged
    return unless repository_folder_changed?
    errors.add(:repo_folder_change, 'repository folder should not be changed once an assignment has been created')
    false
  end

  # Add an error if this the duration attribute is greater than the amount of time
  # between the start_time and due_date.
  #
  # Note that this will fail silently if either the start_time or duration is nil since
  # those values are checked by other validations and so should not be checked twice.
  def start_before_due
    return if start_time.nil? || duration.nil?
    msg = I18n.t('activerecord.errors.models.assignment_properties.attributes.start_time.before_due_date')
    errors.add(:start_time, msg) if start_time > assignment.due_date - duration
  end

  # Add an error if the is_timed and scanned_exam attributes for this assignment
  # are both true.
  def not_timed_and_scanned
    msg = I18n.t('activerecord.errors.models.assignment_properties.attributes.is_timed.not_scanned')
    errors.add(:base, msg) if is_timed && scanned_exam
  end
end
