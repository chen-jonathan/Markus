require 'spec_helper'

describe TestScriptResult do

  it { is_expected.to belong_to(:submission) }
  it { is_expected.to belong_to(:test_script) }
  it { is_expected.to validate_presence_of(:test_script) }
  it { is_expected.to validate_presence_of(:marks_earned) }
  it { is_expected.to validate_presence_of(:repo_revision) }
  it { is_expected.to validate_numericality_of(:marks_earned) }

  context 'test script result' do
    before(:each) do
      @asst = create(:assignment)
      @grouping = create(:grouping, assignment: @asst)
      @sub = create(:submission, grouping: @grouping)
      @test_script = TestScript.create(
        assignment_id: @asst.id,
        seq_num: 1,
        file_name: 'script.sh',
        description: 'This is a bash script file',
        timeout: 30,
        run_by_instructors: true,
        run_by_students: true,
        halts_testing: false,
        display_description: 'do_not_display',
        display_run_status: 'do_not_display',
        display_marks_earned: 'do_not_display',
        display_input: 'do_not_display',
        display_expected_output: 'do_not_display',
        display_actual_output: 'do_not_display'
      )
      @test_script_result = TestScriptResult.create(
        submission: @sub,
        grouping: @sub.grouping,
        test_script: @test_script,
        marks_earned: 1,
        marks_total: 1,
        repo_revision: 0,
        time: 0
      )
    end

    context 'A valid test script result' do

      it 'can have a specified marks total' do
        is_expected.to validate_numericality_of(:marks_total)
        expect(@test_script_result).to be_valid
        expect(@test_script_result.save).to be true
      end

      it 'can have zero marks earned' do
        @test_script_result.marks_earned = 0
        expect(@test_script_result).to be_valid
        expect(@test_script_result.save).to be true
      end

      it 'can have fractional marks earned' do
        @test_script_result.marks_earned = 0.5
        expect(@test_script_result).to be_valid
        expect(@test_script_result.save).to be true
      end

      it 'can have fractional marks total' do
        @test_script_result.marks_total = 1.5
        expect(@test_script_result).to be_valid
        expect(@test_script_result.save).to be true
      end

      it 'can have zero marks total and zero marks earned' do
        @test_script_result.marks_earned = 0
        @test_script_result.marks_total = 0
        expect(@test_script_result).to be_valid
        expect(@test_script_result.save).to be true
      end

      it 'can have a nil marks total' do
        @test_script_result.marks_total = nil
        expect(@test_script_result).to be_valid
        expect(@test_script_result.save).to be true
      end

      it 'can be deleted' do
        expect(@test_script_result).to be_valid
        expect{@test_script_result.destroy}.to change {TestScriptResult.count}.by(-1)
      end
    end

    context 'An invalid test script result' do

      it 'has a nil test script' do
        @test_script_result.test_script = nil
        expect(@test_script_result).not_to be_valid
      end

      it 'has negative marks earned' do
        @test_script_result.marks_earned = -1
        expect(@test_script_result).not_to be_valid
      end

      it 'has negative marks total' do
        @test_script_result.marks_total = -1
        expect(@test_script_result).not_to be_valid
      end

      it 'has marks earned greater than marks total' do
        @test_script_result.marks_earned = 2
        expect(@test_script_result).not_to be_valid
      end

      it 'has negative time' do
        @test_script_result.time = -1
        expect(@test_script_result).not_to be_valid
      end

      it 'has fractional time' do
        @test_script_result.time = 0.5
        expect(@test_script_result).not_to be_valid
      end
    end
  end
end
