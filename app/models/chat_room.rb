require 'time'
require 'securerandom'

class ChatRoom < ActiveRecord::Base
  validates :qiscus_room_name, presence: true
  validates :qiscus_room_id, presence: true
  validates :user_id, presence: true
  validates :application_id, presence: true
  validates :target_user_id, presence: true

  belongs_to :application
  belongs_to :user
  has_many :chat_users
  has_many :users, ->{ order 'users.fullname asc' }, through: :chat_users

  belongs_to :target, :class_name => :User, :foreign_key => "target_user_id"

  has_many :pin_chat_rooms
  has_many :mute_chat_rooms

  default_scope { joins(:user)}

  # Hooks
  after_save :update_sdk_room_info

  # Update redis cache after create, update and delete
  # after save hooks will called both when Creating or Updating an Object
  after_save :update_redis_cache
  after_destroy :update_redis_cache

  def as_json(options={})
    h = super(
      :include =>
        [
          {
            :users =>
            {
              # :include => [
              #   {
              #     :roles =>
              #     {
              #       :only => [:id, :name]
              #     }
              #   },
              #   {
              #     :application => { :only => [:app_name] }
              #   }
              # ],
              :except => [:passcode, :application_id, :qiscus_token, :lock_version],
              :methods => [ :is_admin, :is_official, :additional_infos ]
            } # end of user
          },
          {
            :target =>
            {
              # :include => [
              #   {
              #     :roles =>
              #     {
              #       :only => [:id, :name]
              #     }
              #   },
              #   {
              #     :application => { :only => [:app_name] }
              #   }
              # ],
              :except => [:passcode, :application_id, :qiscus_token, :lock_version],
              :methods => [ :is_admin, :is_official, :additional_infos ]
            } # end of target
          }
        ],
        :except => [:user_id, :group_chat_name, :target_user_id]
    )

    # Overwrite json if has webhook key. This json use only in webhook payload
    if options.has_key?(:webhook)
      h = super(
        :include =>
          [
            {
              :users =>
              {
                :only => [:id, :phone_number, :fullname, :qiscus_email],
              } # end of user
            },
          ],
          :except => [:user_id, :group_chat_name]
      )
    end

    # If has webhook key, doesn't need creator payload
    if !options.has_key?(:webhook)
      h[:creator] = user.as_json
    end

    # manipulate the chat name and private information
    if options.has_key?(:me)
      # if group chat then the group chat name is the group name
      if is_group_chat
        h["chat_name"] = group_chat_name # need to be save in database, but must be hidden property
        # use default group avatar if it's a group chat or 'me' parameter is not assigned
        h["chat_avatar_url"] = group_avatar_url
      else
        # the interlocutor name
        # if fullname is exist then show the fullname, if not show the phone number
        interlocutor = users.where.not(id: options[:me].id).last
        # interlocutor must not be nil, but when it happen whe should prevent it
        if interlocutor.nil?
          h["chat_name"] = ""
          h["chat_avatar_url"] = "" # blank if interlocutor is not found
        else
          h["chat_name"] = (interlocutor.fullname != nil) ? interlocutor.fullname.to_s : interlocutor.phone_number.to_s
          h["chat_avatar_url"] = interlocutor.avatar_url # use user avatar in single chat
        end
      end

      # if is official chat, then using chat bot name
      if is_official_chat
        # if accessed by official account or helpdesk
        if options[:me].is_official || options[:me].is_helpdesk
          # then use group creator name, since it always ordinary user (member)
          h["chat_name"] = user.fullname
          h["chat_avatar_url"] = user.avatar_url
        else
          # else, use official account name (it must be one official account only per official group chat)
          users.each do |u|
            if u.is_official
              h["chat_name"] = u.fullname
              h["chat_avatar_url"] = u.avatar_url
            end
          end
        end

        # use default group avatar if it's a group chat or 'me' parameter is not assigned
        # h["chat_avatar_url"] = group_avatar_url
      end

      # override custom value for users email, gender and date_of_birth
      h["users"].each do |u|
        # if current user, no need to override this information
        if u["id"] != options[:me].id && u["is_public"] == false
          # hide this properties (just set it to empty string for consistent structure)
          u["email"] = ""
          u["gender"] = ""
          u["date_of_birth"] = ""
        end
      end
    else
      h["chat_name"] = group_chat_name
      # use default group avatar if it's a group chat or 'me' parameter is not assigned
      h["chat_avatar_url"] = group_avatar_url
    end

    if options.has_key?(:chat_room_sdk_info)
      # h["unread_count"] = Faker::Number.between(0, 5)
      if options[:chat_room_sdk_info][qiscus_room_id.to_i] != nil
        room_info = options[:chat_room_sdk_info][qiscus_room_id.to_i]

        last_comment_message = room_info["last_comment_message"]
        if last_comment_message.include?"[file]"
          last_comment_message = "File attached."
        end

        h["chat_name_sdk"] = room_info["room_name"]
        h["unread_count"] = room_info["unread_count"]
        h["last_message"] = last_comment_message

        if room_info["last_comment_timestamp"].include?("0001-01-01T00:00:00Z")
          timestamp = Time.parse(created_at.to_s)
          h["last_message_timestamps"] = timestamp.strftime("%Y-%m-%dT%TZ")
        else
          h["last_message_timestamps"] = room_info["last_comment_timestamp"]
        end

        h["group_avatar_url_sdk"] = room_info["room_avatar_url"]

        # use chat_avatar_url from sdk when chat_room_sdk_info assigned
        # only use avatar from SDK if it's a group chat (because latest group avatar is only in SDK [client only update group avatar in SDK])
        if is_group_chat
          h["chat_avatar_url"] = room_info["room_avatar_url"]
        end
      else
        # default value
        h["chat_name_sdk"] = ""
        h["unread_count"] = 0
        h["last_message"] = ""
        h["last_message_timestamps"] = ""
        h["group_avatar_url_sdk"] = ""

        # only use avatar from SDK if it's a group chat (because latest group avatar is only in SDK [client only update group avatar in SDK])
        if is_group_chat
          h["chat_avatar_url"] = ""
        end
      end
    end

    return h
  end

  # Updating all chat room name in SDK to chat room in backend.
  # This is to make name in SDK is same with data in backend (when load conversation list).
  # This should called once before after save and after update hooks implemented.
  def self.update_all_group_chat_room_sdk_name(application)
    chat_rooms = ChatRoom.where(application_id: application.id).all
    chat_rooms.each do | chat_room |
      # update group name in sdk info from back-end
      participants = chat_room.users.first
      if !participants.nil? && chat_room.is_group_chat == true
        password = SecureRandom.hex # generate random password for security reason
        qiscus_sdk = QiscusSdk.new(participants.application.app_id, participants.application.qiscus_sdk_secret)

        token = qiscus_sdk.login_or_register_rest(participants.qiscus_email, password, participants.fullname,
          participants.avatar_url)

        participants.update_attribute(:qiscus_token, token)

        qiscus_sdk.update_room(token, chat_room.qiscus_room_id, chat_room.group_chat_name,
          chat_room.group_avatar_url)
      end

    end
  end

  def update_sdk_room_info
    begin
      Rails.logger.debug "Update SDK Room Info"
      if is_group_chat
        participants = users.first
        password = SecureRandom.hex # generate random password for security reason
        qiscus_sdk = QiscusSdk.new(participants.application.app_id, participants.application.qiscus_sdk_secret)

        # to avoid error if user token changed in sdk
        token = qiscus_sdk.login_or_register_rest(participants.qiscus_email, password, participants.fullname,
            participants.avatar_url)

        participants.update_attribute(:qiscus_token, token)

        qiscus_sdk.update_room(token, qiscus_room_id, group_chat_name, group_avatar_url)
      end
    rescue Exception => e
      Rails.logger.debug "Fail when call SDK: #{e.message}"
    end
  end

  # Delete and update redis cache for conversation list to make all data sync after update
  def update_redis_cache
    user_ids = ChatUser.where(chat_room_id: id).pluck(:user_id)
    ChatRoomHelper.reset_chat_room_cache_for_users(user_ids)
  end

  # Update all avatar_url since it change to https
  def self.update_all_avatar_url_to_https
    chat_rooms = ChatRoom.where('group_avatar_url LIKE ?', 'http://%')
    chat_rooms.each do | c |
      old_group_avatar_url = c.group_avatar_url
      size = old_group_avatar_url.size
      raw_group_avatar_url = old_group_avatar_url[7...size]
      new_group_avatar_url = "https://" + raw_group_avatar_url;
      c.update_attribute(:group_avatar_url, new_group_avatar_url)
    end
  end

  def self.check_single_chat_room_which_contains_only_one_user
    chat_rooms = ChatRoom.where(is_group_chat: false).pluck(:id) # get all chat_room
    single_chat_user = Array.new

    chat_rooms.each do | c |
      chat_user_count = ChatUser.where(chat_room_id: c).count # count chat_room participants

      # Get chat_room which contains only one participant
      if chat_user_count == 1
        single_chat_user.push(c)
      end
    end

    puts "Single chat room which contains only one user : #{single_chat_user}"
    puts "Total : #{single_chat_user.count}"
  end

  def self.insert_another_participant_into_single_chat_room_which_contains_only_one_user
    chat_rooms = ChatRoom.where(is_group_chat: false).pluck(:id, :user_id, :target_user_id) # get all chat_room

    chat_rooms.each do | c |
      chat_user = ChatUser.where(chat_room_id: c[0]) # c[0] mean chat_room_id
      chat_user_count = chat_user.count # count chat_room participants

      # Get chat_room which contains only one participant
      if chat_user_count == 1
        # get chat_room participant
        single_participant = chat_user.pluck(:user_id).first

        user_id = c[1] # c[1] mean user_id
        target_user_id = c[2] # c[2] mean target_user_id

        if single_participant == user_id and user_id != target_user_id
          chat_user = ChatUser.new
          chat_user.user_id = target_user_id
          chat_user.chat_room_id = c[0]
          chat_user.is_group_admin = false
          chat_user.save!
        elsif single_participant == target_user_id and user_id != target_user_id
          chat_user = ChatUser.new
          chat_user.user_id = user_id
          chat_user.chat_room_id = c[0]
          chat_user.is_group_admin = false
          chat_user.save!
        end
      end
    end

  end

  def self.delete_single_chat_room_which_contains_only_one_user
    chat_rooms = ChatRoom.where(is_group_chat: false).pluck(:id) # get all chat_room
    single_chat_user = Array.new

    chat_rooms.each do | c |
      chat_user = ChatUser.where(chat_room_id: c)
      chat_user_count = chat_user.count # count chat_room participants

      # Get chat_room which contains only one participant
      if chat_user_count == 1
        single_chat_user.push(c)
        ChatRoom.find(c).destroy
      end
    end

    puts "Single chat room which contains only one user : #{single_chat_user}"
    puts "Total : #{single_chat_user.count}"
  end

end