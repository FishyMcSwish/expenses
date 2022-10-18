# frozen_string_literal: true

require 'csv'

class Utils
  def self.to_hash(record)
    hash = {}
    record.instance_variables.each do |var|
      hash[var.to_s.delete('@')] = record.instance_variable_get(var)
    end
    hash
  end
end
INFLATION_RATE = 0.03
INFINITE_DURATION = :infinite
EXPIRED_DURATION = :expired
##
# base class for expenses and income
class BudgetItem
  attr_accessor :name, :amount, :rate_of_increase, :duration

  def initialize(name, amount, rate_of_increase = INFLATION_RATE, duration = INFINITE_DURATION)
    @name = name
    @amount = amount
    @rate_of_increase = rate_of_increase
    @duration = duration
  end

  ##
  # a doc
  def annual_increase
    new_duration = (duration.is_a? Integer) ? duration - 1 : duration
    new_amount = amount * rate_of_increase + amount
    if [EXPIRED_DURATION, 0].include?(new_duration)
      BudgetItem.new(name, 0, 0, EXPIRED_DURATION)
    else
      BudgetItem.new(name, new_amount, rate_of_increase, new_duration)
    end
  end

  def isExpired?
    duration == EXPIRED_DURATION
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
    if other.nil? && nil?
      true
    elsif nil?
      false
    else
      name == other.name && amount == other.amount && rate_of_increase == other.rate_of_increase && self.duration = other.duration
    end
  end

  def to_h
    Utils.to_hash(self)
  end
end

class Account
  attr_accessor :name, :amount, :rate_of_increase

  def initialize(name, amount, rate_of_increase)
    @name = name
    @amount = amount
    @rate_of_increase = rate_of_increase
  end

  def annual_increase
    Account.new(@name, @amount + @amount * @rate_of_increase, @rate_of_increase)
  end

  def add(change)
    Account.new(name, amount + change, rate_of_increase)
  end

  def ==(other)
    if other.nil? && nil?
      true
    elsif nil?
      false
    else
      name == other.name && amount == other.amount && rate_of_increase == other.rate_of_increase
    end
  end
end

class Year
  attr_accessor :items, :accounts

  def initialize(items = [], accounts = [])
    @items = items
    @accounts = accounts
  end

  def nextYear
    increased_accounts = accounts.map do |acct|
      acct.name == 'investments' ? acct.annual_increase.add(extraCash) : acct.annual_increase
    end
    Year.new(items.map(&:annual_increase), increased_accounts)
  end

  def extraCash
    items.reduce(0) { |sum, item| sum + item.amount }
  end

  def merge(other)
    other.nil? ? self : Year.new(items + other.items, accounts + other.accounts)
  end

  def to_h
    { 'items' => items.map { |item| item.to_h } }
  end
end

class Plan
  attr_accessor :current_year

  def initialize(years, current_year = 0)
    @years = years
    @current_year = current_year
  end

  def years
    Hash[@years.sort_by { |k, _v| k }]
  end

  def run_years(num_of_years)
    current_year = self.current_year
    new_years = @years.merge
    while current_year < num_of_years
      nextYear = new_years[current_year].nextYear
      current_year += 1
      existing_year = new_years[current_year]
      new_years[current_year] = nextYear.merge(existing_year)
    end
    Plan.new(new_years, current_year)
  end

  def toCSV
    years.map { |k, year| [k, year.to_h] }.to_h
  end
end
