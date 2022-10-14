# frozen_string_literal: true
require 'budget_items'

describe 'Finances' do
  describe 'Budget Items' do
    describe 'constructors' do

      it 'has default params' do
        expect(BudgetItem.new("test", 100)).to eq(BudgetItem.new("test", 100, INFLATION_RATE, INFINITE_DURATION))
      end
      it 'expenses are negative' do 
        exp = BudgetItem.recurring_expense("kids", 100)
        expect(exp).to eq(BudgetItem.new("kids", -100))
      end

      it 'deposits are positive' do
        income = BudgetItem.recurring_income("work", 100)
        expect(income).to eq(BudgetItem.new("work", 100))
      end
      
      it "expired items are expired" do
        item = BudgetItem.new("test", 0, 0, EXPIRED_DURATION)
        expect(item.isExpired?).to eq(true)
      end
      it "items with duration left are not expired" do
        item1 = BudgetItem.new("test", 0, 0, 1)
        item2 = BudgetItem.new("test", 0, 0, INFINITE_DURATION)
        expect(item1.isExpired?).to eq(false)
        expect(item2.isExpired?).to eq(false)
      end
      it "one time expenses" do
        exp = BudgetItem.one_time_expense("kids", 100)
        expect(exp).to eq(BudgetItem.new("kids", -100, 0, 1))
      end
      it "one time income" do
        exp = BudgetItem.one_time_income("kids", 100)
        expect(exp).to eq(BudgetItem.new("kids", 100, 0, 1))
      end

    end

    describe 'annual increases' do
      it 'increase at the specified rate' do
        item = BudgetItem.new("test", 100, 0.05)
        expect(item.annual_increase.amount).to eq(105)
      end
    end
    it "doesn't change the duration on infinite duration items" do
      year1 = BudgetItem.recurring_expense("test", 100)
      year2 = year1.annual_increase
      expect(year2.duration).to eq(INFINITE_DURATION)
    end
    it "changes the duration for finite duration items" do
      year1 = BudgetItem.new("test", 100, INFLATION_RATE, 100)
      year2 = year1.annual_increase
      expect(year2.duration).to eq(99)
    end
    it "returns an expired expense if the duration is over" do
      year1 = BudgetItem.new("test", 100, INFLATION_RATE, 1)
      year2 = year1.annual_increase
      expect(year2).to eq(BudgetItem.new("test", 0, 0, EXPIRED_DURATION))
    end
  end
  describe 'Years' do
    describe 'nextYear' do
      it 'increases all the items' do
        year1 = Year.new([BudgetItem.recurring_expense("kids", 100), BudgetItem.recurring_income("work", 100)])
        year2 = year1.nextYear()
        expect(year2.items.map {|item| item.amount}).to  eq([-103, 103])
      end
    end
    describe 'extraCash' do
      it 'adds up the items' do
        year1 = Year.new([BudgetItem.recurring_expense("kids", 100), BudgetItem.recurring_income("work", 100)])
        expect(year1.extraCash).to eq 0
      end
    end
    describe 'merge' do
      it 'merges two years items' do
        year1 = Year.new([BudgetItem.recurring_expense("kids", 100)])
        year2 = Year.new([BudgetItem.recurring_expense("kids", 100)])
        expect(year1.merge(year2).items.length).to eq(2)
      end
    end

  end
  describe 'Plans' do
    it 'generates future years from one year of data' do
      year0 = Year.new([BudgetItem.recurring_expense("kids", 100), BudgetItem.recurring_income("income", 100)])
      plan = Plan.new({0 => year0})
      ten_year_plan = plan.run_years(10)
      expect(ten_year_plan.years.length).to eq(11)
      expect(ten_year_plan.current_year).to eq(10)
      expect(ten_year_plan.years[10].items[1].amount).to eq(134.3916379344122)
    end
    it 'generates future years with correct data' do
      year0 = Year.new([BudgetItem.recurring_expense("kids", 100), BudgetItem.recurring_income("income", 200)])
      plan = Plan.new({0 => year0})
      three_year_plan = plan.run_years(3)
      amounts = three_year_plan.years.map {|k, v| v.extraCash}
      expect(amounts).to eq([100, 103.0, 106.09, 109.2727])
    end
    it 'treats one time expenses in year 0 properly' do
      year0 = Year.new([BudgetItem.recurring_expense("kids", 100), BudgetItem.recurring_income("income", 200), BudgetItem.one_time_expense("onetime", 100)])
      plan = Plan.new({0 => year0})
      three_year_plan = plan.run_years(3)
      amounts = three_year_plan.years.map {|k, v| v.extraCash}
      expect(amounts).to eq([0, 103.0, 106.09, 109.2727])
    end
    it 'treats future year one time expenses properly' do
      year0 = Year.new([BudgetItem.recurring_expense("kids", 100), BudgetItem.recurring_income("income", 200)])
      year3 = Year.new([BudgetItem.one_time_expense("kids", 100)])
      plan = Plan.new({0 => year0, 3 => year3})
      three_year_plan = plan.run_years(3)
      amounts = three_year_plan.years.map {|k, v| v.extraCash}
      expect(amounts).to eq([100, 103.0, 106.09, 9.2727])
    end
  end
end

