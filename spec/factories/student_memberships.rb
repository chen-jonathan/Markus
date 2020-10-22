FactoryBot.define do
  factory :student_membership, class: StudentMembership, parent: :membership do
    association :user, factory: :student
    association :grouping
    membership_status {StudentMembership::STATUSES[:pending]}

    factory :inviter_student_membership do
      membership_status { StudentMembership::STATUSES[:inviter] }
    end

    factory :accepted_student_membership do
      membership_status { StudentMembership::STATUSES[:accepted] }
    end

    factory :rejected_student_membership do
      membership_status { StudentMembership::STATUSES[:rejected] }
    end
  end

  factory :test_student_membership, class: StudentMembership, parent: :membership do
    association :user, factory: :test_student
    association :grouping
    membership_status { StudentMembership::STATUSES[:inviter] }
  end
end
