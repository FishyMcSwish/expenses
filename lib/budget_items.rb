# frozen_string_literal: true

  INFLATION_RATE = 0.03
  INFINITE_DURATION = :infinite
  EXPIRED_DURATION = :expired
  ##
  # base class for expenses and income
  class BudgetItem
    attr_accessor :name, :amount, :rate_of_increase, :duration

    def initialize(name, amount, rate_of_increase=INFLATION_RATE, duration=INFINITE_DURATION)
      @name = name
      @amount = amount
      @rate_of_increase = rate_of_increase 
      @duration = duration
    end

    ##
    # a doc
    def annual_increase()
      new_duration = (self.duration.is_a? Integer) ? self.duration - 1 : self.duration
      new_amount = self.amount * self.rate_of_increase + self.amount
      if(new_duration == EXPIRED_DURATION || new_duration == 0)
        return BudgetItem.new(self.name, 0, 0, EXPIRED_DURATION)
      else 
        return BudgetItem.new(self.name, new_amount, self.rate_of_increase, new_duration)
      end
    end

    def isExpired?()
      self.duration == EXPIRED_DURATION
    end

    def self.recurring_expense(name, amount)
      BudgetItem.new(name, -amount)
    end
    def self.one_time_expense(name, amount)
      BudgetItem.new(name, -amount, 0, 1)
    end

    def self.recurring_income(name, amount)
      BudgetItem.new(name, amount)
    end
    def self.one_time_income(name, amount)
      BudgetItem.new(name, amount, 0, 1)
    end

    def ==(other)
      if(other.nil? && self.nil?)
        return true
      elsif(self.nil?)
        return false
      else
        return self.name == other.name && self.amount == other.amount && self.rate_of_increase == other.rate_of_increase && self.duration = other.duration
      end
    end
  end

  class Year
    attr_accessor :items
    def initialize(items)
      @items = items
    end
    def nextYear()
      Year.new(self.items.map { |item| item.annual_increase()})
    end
    def extraCash()
      self.items.reduce(0){|sum, item| sum + item.amount}
    end
    def merge(other)
      other.nil? ? self : Year.new(self.items + other.items)
    end
  end

  class Plan
    attr_accessor :current_year
    def initialize(years, current_year=0)
      @years = years
      @current_year = current_year
    end

    def years
      Hash[@years.sort_by {|k,v| k}]
    end
    
    def run_years(num_of_years)
      current_year = self.current_year
      new_years = @years.merge
      while current_year < num_of_years
        next_year = new_years[current_year].nextYear()
        current_year += 1
        existing_year = new_years[current_year]
        new_years[current_year] = next_year.merge(existing_year)
      end
      Plan.new(new_years, current_year)
    end
end


