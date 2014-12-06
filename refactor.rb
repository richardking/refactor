# Controller

class People < ActionController::Base

  # ... Other REST actions

  def create
    @person = Person.new(params[:person])

    team_name = if Person.counter.odd?
                  "UnicornRainbows"
                else
                  "LaserScorpions"
                end

    @person.assign_labels(team_name)

    if @person.save
      UserEmailer.validate_email(@person).deliver
      AdminEmailer.new_user(@person).deliver
      redirect_to @person, :notice => "Account added!"
    else
      render :new
    end
  end

  def validate_email
    if (@user = Person.find_by_slug(params[:slug]))
      @user.validate!
      Rails.logger.info "USER: User ##{@user.id} validated email successfully."
      AdminEmailer.user_validated(@user).deliver
      UserEmailer.welcome(@user).deliver
    end
  end

end


# Model

class Person < ActiveRecord::Base
  attr_accessible :first_name, :last_name, :email, :admin, :slug, :validated, :handle, :team

  scope :admins, lambda { where(admin: true) }
  scope :over_30_days, lambda { where("created_at < ?", Time.now - 30.days) }
  scope :unvalidated, lambda { where(validated: false) }

  before_create :add_slug

  class << self
    def counter
      count + 1
    end
  end

  def validate!
    self.validate = true
    self.save
  end

  def add_slug
    self.slug = "ABC123#{Time.now.to_i.to_s}1239827#{rand(10000)}"
  end

  def assign_labels(team_name)
    self.team = team_name
    self.handle = team_name + (Person.counter).to_s
  end
end


# Mailer

class UserEmailer < ActionMailer::Base
  default from: "foo@example.com"

  def welcome(person)
    @person = person
    mail to: @person.email
  end

  def validate_email(person)
    @person = person
    mail to: @person.email
  end

end

class AdminEmailer < ActionMailer::Base
  default to: Proc.new { Person.admins.pluck(:email) },
    from: "foo@example.com"

  def user_validated(user)
    @user = user
    mail
  end

  def new_user(user)
    @user = user
    mail
  end

  def removing_unvalidated_users(users)
    @users = users
    mail
  end

end


# Rake Task

namespace :accounts do

  desc "Remove accounts where the email was never validated and it is over 30 days old"
  task :remove_unvalidated do
    @people = Person.over_30_days.unvalidated
    @people.each do |person|
      Rails.logger.info "Removing unvalidated user #{person.email}"
      person.destroy
    end
    AdminEmailer.removing_unvalidated_users(@people).deliver
  end

end
