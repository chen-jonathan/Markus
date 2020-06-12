describe Mark do
  it { is_expected.to validate_presence_of(:markable_type) }

  it { is_expected.to belong_to(:markable) }
  it { is_expected.to belong_to(:result) }

  it { is_expected.to allow_value('RubricCriterion').for(:markable_type) }
  it { is_expected.to allow_value('FlexibleCriterion').for(:markable_type) }
  it { is_expected.to_not allow_value('').for(:markable_type) }
  it { is_expected.to_not allow_value(nil).for(:markable_type) }
  it { is_expected.to allow_value(false).for(:override) }
  it { is_expected.to allow_value(true).for(:override) }
  it { is_expected.to_not allow_value(nil).for(:override) }

  describe 'when markable type is rubric and the max mark is exceeded' do
    let(:rubric_mark) do
      FactoryBot.build(:rubric_mark, mark: 10)
    end
    it 'should not be valid' do
      expect(rubric_mark).to_not be_valid
    end
  end

  describe 'when markable type is flexible and the max mark is exceeded' do
    let(:flexible_mark) do
      FactoryBot.build(:flexible_mark, mark: 10)
    end
    it 'should not be valid' do
      expect(flexible_mark).to_not be_valid
    end
  end

  describe 'when markable type is flexible and the max mark is exceeded' do
    let(:checkbox_mark) do
      FactoryBot.build(:checkbox_mark, mark: 10)
    end
    it 'should not be valid' do
      expect(checkbox_mark).to_not be_valid
    end
  end

  describe 'when mark is less than 0' do
    let(:rubric_mark) do
      FactoryBot.build(:rubric_mark, mark: -1)
    end
    it 'should not be valid' do
      expect(rubric_mark).to_not be_valid
    end
  end

  describe 'mark (column in marks table)' do
    let(:rubric_mark) do
      FactoryBot.create(:rubric_mark, mark: 4)
    end
    it 'equals to mark times weight' do
      markable = RubricCriterion.find(rubric_mark.markable_id)
      expect(rubric_mark.mark).to eq(markable.weight)
    end
  end

  describe '#scale_mark' do
    let(:curr_max_mark) { 10 }
    describe 'when mark is a rubric mark' do
      let(:mark) { create(:rubric_mark, mark: 3) }
      it_behaves_like 'Scale_mark'
    end
    describe 'when mark is a flexible mark' do
      let(:mark) { create(:flexible_mark, mark: 1) }
      it_behaves_like 'Scale_mark'
    end
    describe 'when mark is a checkbox mark' do
      let(:mark) { create(:checkbox_mark, mark: 1) }
      it_behaves_like 'Scale_mark'
    end
  end

  describe '#calculate_deduction' do
    let(:assignment) { create(:assignment_with_deductive_annotations) }
    let(:annotation_category_with_criteria) do
      assignment.annotation_categories.where.not(flexible_criterion_id: nil).first
    end
    let(:result) { assignment.groupings.first.current_result }
    let(:annotation_text) { annotation_category_with_criteria.annotation_texts.first }
    let(:mark) { result.marks.first }

    it 'calculates the correct deduction when one annotation is applied' do
      deducted = mark.calculate_deduction
      expect(deducted).to eq(1.0)
    end

    it 'calculates the correct deduction when multiple annotations are applied' do
      create(:text_annotation,
             annotation_text: annotation_text,
             result: result)
      deducted = mark.calculate_deduction
      expect(deducted).to eq(2.0)
    end
  end

  describe '#update_deduction' do
    let(:assignment) { create(:assignment_with_deductive_annotations) }
    let(:annotation_category_with_criteria) do
      assignment.annotation_categories.where.not(flexible_criterion_id: nil).first
    end
    let(:result) { assignment.groupings.first.current_result }
    let(:annotation_text) { annotation_category_with_criteria.annotation_texts.first }
    let(:mark) { result.marks.first }

    it 'changes the mark correctly to reflect deductions when there are deductions with the same values' do
      create(:text_annotation,
             annotation_text: annotation_text,
             result: result)
      result.reload
      expect(mark.mark).to eq(1.0)
    end

    it 'changes the mark correctly to reflect deductions when there are deductions with different values' do
      new_text = create(:annotation_text_with_deduction,
                        deduction: 1.5,
                        annotation_category: annotation_category_with_criteria)
      create(:text_annotation,
             annotation_text: new_text,
             result: result)
      result.reload
      expect(mark.mark).to eq(0.5)
    end

    it 'does not change the mark if override is enabled' do
      mark.update!(mark: 3.0)
      mark.update!(override: true)
      create(:text_annotation,
             annotation_text: annotation_text,
             result: result)
      result.reload
      expect(mark.mark).to eq(3.0)
    end

    it 'does not allow deductions to reduce the mark past 0' do
      3.times do
        create(:text_annotation,
               annotation_text: annotation_text,
               result: result)
      end
      result.reload
      expect(mark.mark).to eq(0.0)
    end

    it 'does not change the mark when there are no deductions' do
      assignment_without_deductions = create(:assignment_with_criteria_and_results)
      grouping_with_result = assignment_without_deductions.groupings.where.not(current_result: nil).first
      mark_without_deductions = grouping_with_result.current_result.marks.first
      mark_without_deductions.update_deduction
      mark_without_deductions.reload
      expect(mark_without_deductions.mark).to eq(nil)
    end

    it 'does not take into account deductions related to other criteria' do
      new_criterion = create(:flexible_criterion_with_annotation_category,
                             assignment: assignment)
      create(:mark,
             markable_id: new_criterion.id,
             markable_type: 'FlexibleCriterion',
             result: result)
      new_annotation_text = create(:annotation_text_with_deduction,
                                   annotation_category: new_criterion.annotation_categories.first)
      create(:text_annotation,
             annotation_text: new_annotation_text,
             result: result)
      mark.update_deduction
      mark.reload
      expect(mark.mark).to eq(2.0)
    end

    it 'does not update the mark to max_mark value when there are no annotations' do
      result.annotations.destroy_all # update deduction called in annotation callback
      expect(mark.reload.mark).to eq(nil)
    end

    it 'does not update the mark to max_mark value when there are only deductive annotations with 0 value deductions' do
      annotation_text.update!(deduction: 0) # update deduction called in annotation_text callback
      expect(mark.reload.mark).to eq(nil)
    end

    it 'updates the override of a mark to false when last deductive annotation deleted if the override '\
       'was true before and the mark was nil' do
      mark.update!(mark: nil, override: true)
      result.annotations.joins(annotation_text: :annotation_category)
            .where('annotation_categories.flexible_criterion_id': mark.markable_id).first.destroy
      expect(mark.reload.override).to be false
    end
  end

  describe '#ensure_mark_value' do
    it 'updates the mark value to be calculated from annotation deductions if override changed to false' do
      assignment = create(:assignment_with_deductive_annotations)
      mark = assignment.groupings.first.current_result.marks.first
      mark.update!(override: true, mark: mark.markable.max_mark)
      mark.update!(override: false)
      expect(mark.reload.mark).to eq 2.0
    end
  end
  # private methods
  describe '#ensure_not_released_to_students'
  describe '#update_grouping_mark'
end
