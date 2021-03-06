class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: %i[facebook]

  validates :first_name, presence: true, length: { maximum: 20 },
  format: { with: /[a-z]+/i }
  validates :last_name, presence: true, length: { maximum: 20 },
  format: { with: /[a-z]+/i }

  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy

  has_many :friend_requests_sent, foreign_key: :sender_id,
          class_name: "FriendRequest", dependent: :destroy

  has_many :friend_requests_received, foreign_key: :receiver_id,
          class_name: "FriendRequest", dependent: :destroy


  has_many :friendships, foreign_key: :adder_id, dependent: :destroy
  has_many :friendships_2, class_name: "Friendship", foreign_key: :added_id,
            dependent: :destroy

  has_many :friends, through: :friendships, source: :added





  def friendable_users

    friends               = self.friends.ids
    sent_request_to       = self.friend_requests_sent.pending.pluck(:receiver_id)
    received_request_from = self.friend_requests_received.pending.pluck(:sender_id)
    friend_or_has_pending_request = friends + [self.id] + sent_request_to + received_request_from
    @users = User.all.where.not("id IN (?)", friend_or_has_pending_request)

  end


  def establish_friendship(other_user)
    begin
      self.friends.push(other_user)
      other_user.friends.push(self)
    rescue ActiveRecord::RecordNotUnique
      self.errors.add(:friends, "You're already friends")
      other_user.errors.add(:friends, "You're already friends")
    end
  end

  def destroy_friendship(other_user)
    self.friends.delete(other_user)
    other_user.friends.delete(self)
  end

  def feed
    friends_ids = self.friends.ids.join(',')
    unless friends_ids.blank?
      Post.where("user_id IN (#{friends_ids})
                OR user_id = :user_id", user_id: id)
    else
      Post.where("user_id = :user_id", user_id: id)
    end
  end

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.password = Devise.friendly_token[0, 20]
      user.first_name = auth.info.name.split(' ')[0]
      user.last_name = auth.info.name.split(' ')[-1]
    end
  end

  after_create :welcome_send

  def welcome_send
    # UserMailer.with(user: @user).welcome_email.deliver_now
    UserMailer.with(user: self).welcome_email.deliver_now
  end



end
