class User < ActiveRecord::Base
  include Concerns::Roles

  devise :database_authenticatable,
    :registerable,
    :recoverable,
    :rememberable,
    :trackable,
    :omniauthable, omniauth_providers: [:github],
    authentication_keys: [:login]

  has_many :lesson_users
  has_many :lessons, through: :lesson_users
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  has_paper_trail
  after_create :send_welcome_email

  attr_accessor :login

  def self.find_first_by_auth_conditions(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions).where(['lower(name) = :value OR lower(email) = :value', { value: login.downcase }]).first
    else
      if conditions[:name].nil?
        where(conditions).first
      else
        where(name: conditions[:name]).first
      end
    end
  end

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.name = auth.info.name   # assuming the user model has a name
    end
  end

  def self.new_with_session(params, session)
    super.tap do |user|
      if data = session['devise.github_data'] && session['devise.github_data']['extra']['raw_info']
        user.email = data['email'] if user.email.blank?
      end
    end
  end

  def send_welcome_email
    UserMailer.welcome_email(self).deliver_now
  end

  def completed_lesson(section_lesson_id)
    lessons.where(id: section_lesson_id).first
  end

  def current_lesson(section_lesson_id)
    lessons.where(id: section_lesson_id).first
  end

  def next_lesson(completed_by_user_lesson)
    lessons.where(id: completed_by_user_lesson.id+1).first
  end

  def last_lesson(section_id)
    lessons.where(section_id: section_id).last
  end

  def lessons_length(completed_by_user_lesson)
    lessons.where(id: completed_by_user_lesson.id).count
  end

  def completed_lessons(course)
    course_lessons = course.lessons.map(&:id)
    completed = lesson_users.where(lesson_id: course_lessons).count
    all_lessons = course.lessons.count
    completed.to_f * 100.0 / all_lessons.to_f
  end

end
