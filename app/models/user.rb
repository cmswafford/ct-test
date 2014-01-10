class User < ActiveRecord::Base
	serialize :recent_tweets
	serialize :friends
end
