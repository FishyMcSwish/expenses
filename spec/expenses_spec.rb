# frozen_string_literal: true

require 'budget_items'
require 'data'

describe 'Finances' do
  describe 'Budget Items' do
    describe 'constructors' do
      it 'has default params' do
        expect(BudgetItem.new('test', 100)).to eq(BudgetItem.new('test', 100, INFLATION_RATE, INFINITE_DURATION))
      end
      it 'expenses are negative' do
        exp = BudgetItem.recurring_expense('kids', 100)
        expect(exp).to eq(BudgetItem.new('kids', -100))
      end

      it 'deposits are positive' do
        income = BudgetItem.recurring_income('work', 100)
        expect(income).to eq(BudgetItem.new('work', 100))
      end

      it 'expired items are expired' do
        item = BudgetItem.new('test', 0, 0, EXPIRED_DURATION)
        expect(item.isExpired?).to eq(true)
      end
      it 'items with duration left are not expired' do
        item1 = BudgetItem.new('test', 0, 0, 1)
        item2 = BudgetItem.new('test', 0, 0, INFINITE_DURATION)
        expect(item1.isExpired?).to eq(false)
        expect(item2.isExpired?).to eq(false)
      end
      it 'one time expenses' do
        exp = BudgetItem.one_time_expense('kids', 100)
        expect(exp).to eq(BudgetItem.new('kids', -100, 0, 1))
      end
      it 'one time income' do
        exp = BudgetItem.one_time_income('kids', 100)
        expect(exp).to eq(BudgetItem.new('kids', 100, 0, 1))
      end
    end
    describe 'annual increases' do
      it 'increase at the specified rate' do
        item = BudgetItem.new('test', 100, 0.05)
        expect(item.annual_increase.amount).to eq(105)
      end
      it "doesn't change the duration on infinite duration items" do
        year1 = BudgetItem.recurring_expense('test', 100)
        year2 = year1.annual_increase
        expect(year2.duration).to eq(INFINITE_DURATION)
      end
      it 'changes the duration for finite duration items' do
        year1 = BudgetItem.new('test', 100, INFLATION_RATE, 100)
        year2 = year1.annual_increase
        expect(year2.duration).to eq(99)
      end
      it 'returns an expired expense if the duration is over' do
        year1 = BudgetItem.new('test', 100, INFLATION_RATE, 1)
        year2 = year1.annual_increase
        expect(year2).to eq(BudgetItem.new('test', 0, 0, EXPIRED_DURATION))
      end
    end
    it 'to_h' do
      item = BudgetItem.new('test', 100, INFLATION_RATE, INFINITE_DURATION)
      expect(item.to_h).to eq({ 'name' => 'test', 'amount' => 100, 'rate_of_increase' => INFLATION_RATE,
                                'duration' => :infinite })
    end
  end

  describe 'Accounts' do
    it 'does an annual increase' do
      acct = Account.new('investments', 100, -0.05)
      expect(acct.annual_increase).to eq(Account.new('investments', 95, -0.05))
    end
  end

  describe 'Years' do
    describe 'nextYear' do
      it 'increases all the items' do
        year1 = Year.new([BudgetItem.recurring_expense('kids', 100), BudgetItem.recurring_income('work', 100)],
                         [Account.new('acct', 100, 0.05)])
        year2 = year1.nextYear
        expect(year2.items.map(&:amount)).to eq([-103, 103])
        expect(year2.accounts.map(&:amount)).to eq([105])
      end
      it 'adds extra cash to investment account' do
        year1 = Year.new([BudgetItem.new('kids', -100, 0, INFINITE_DURATION),
                          BudgetItem.new('income', 200, 0, INFINITE_DURATION)],
                         [Account.new('investments', 0, 0)])
        year2 = year1.nextYear
        expect(year2.accounts[0].amount).to eq(100)
      end
    end
    describe 'extraCash' do
      it 'adds up the items' do
        year1 = Year.new([BudgetItem.recurring_expense('kids', 100), BudgetItem.recurring_income('work', 100)])
        expect(year1.extraCash).to eq 0
      end
    end
    describe 'merge' do
      it 'merges two years items' do
        year1 = Year.new([BudgetItem.recurring_expense('kids', 100)], [Account.new('acct', 100, 0)])
        year2 = Year.new([BudgetItem.recurring_expense('kids', 100)], [Account.new('acct', 100, 0)])
        merged = year1.merge(year2)
        expect(merged.items.length).to eq(2)
        expect(merged.accounts.length).to eq(2)
      end
    end
  end

  describe 'Plans' do
    describe 'generating future years' do
      it 'generates future years from one year of data' do
        year0 = Year.new([BudgetItem.recurring_expense('kids', 100), BudgetItem.recurring_income('income', 100)])
        plan = Plan.new({ 0 => year0 })
        ten_year_plan = plan.run_years(10)
        expect(ten_year_plan.years.length).to eq(11)
        expect(ten_year_plan.current_year).to eq(10)
        expect(ten_year_plan.years[10].items[1].amount).to eq(134.3916379344122)
      end
      it 'generates future years with correct extra cash' do
        year0 = Year.new([BudgetItem.recurring_expense('kids', 100), BudgetItem.recurring_income('income', 200)])
        plan = Plan.new({ 0 => year0 })
        three_year_plan = plan.run_years(3)
        cash_amounts = three_year_plan.years.map { |_k, v| v.extraCash }
        expect(cash_amounts).to eq([100, 103.0, 106.09, 109.2727])
      end
      it 'treats one time expenses in year 0 properly' do
        year0 = Year.new([BudgetItem.recurring_expense('kids', 100), BudgetItem.recurring_income('income', 200),
                          BudgetItem.one_time_expense('onetime', 100)])
        plan = Plan.new({ 0 => year0 })
        three_year_plan = plan.run_years(3)
        amounts = three_year_plan.years.map { |_k, v| v.extraCash }
        expect(amounts).to eq([0, 103.0, 106.09, 109.2727])
      end
      it 'treats future year one time expenses properly' do
        year0 = Year.new([BudgetItem.recurring_expense('kids', 100), BudgetItem.recurring_income('income', 200)])
        year3 = Year.new([BudgetItem.one_time_expense('kids', 100)])
        plan = Plan.new({ 0 => year0, 3 => year3 })
        three_year_plan = plan.run_years(3)
        amounts = three_year_plan.years.map { |_k, v| v.extraCash }
        expect(amounts).to eq([100, 103.0, 106.09, 9.2727])
      end
    end
    describe 'CSV conversion' do
      it 'prepares for csv conversion properly' do
        year0 = Year.new([BudgetItem.recurring_expense('kids', 100), BudgetItem.recurring_income('income', 200)])
        year3 = Year.new([BudgetItem.one_time_expense('kids', 100)])
        plan = Plan.new({ 0 => year0, 3 => year3 })
        csvs = plan.toCSV
        expect(csvs).to eq({ 0 => {
                               'items' => [{ 'name' => 'kids', 'amount' => -100, 'rate_of_increase' => 0.03, 'duration' => :infinite },
                                           { 'name' => 'income', 'amount' => 200, 'rate_of_increase' => 0.03,
                                             'duration' => :infinite }]
                             },
                             3 => { 'items' => [{ 'name' => 'kids', 'amount' => -100, 'rate_of_increase' => 0,
                                                  'duration' => 1 }] } })
      end
    end
  end
  describe 'my plan' do
    it 'looks good?' do
      result = MY_PLAN.run_years(30)
      puts result.years[30].accounts.map { |a| [a.name, a.amount] }
    end
  end
end
