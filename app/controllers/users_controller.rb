require 'time'
require 'twitter'

class UsersController < ApplicationController
	def create(screen_name)
		user = User.new(:screen_name => screen_name, :recent_tweets => '', :friends => '')
		user.save
	end

	def recent_tweets
		# id == 0 used to display the input form
		unless params[:id] == "0"
			screen_name = params[:id]
			@tweets = get_recent_tweets(screen_name)
			@username = screen_name
		end
	end

	def intersect_friends
		unless params[:screen_names].blank?
			@screen_names = params[:screen_names]
			user0_friends = get_friends(@screen_names[0])
			user1_friends = get_friends(@screen_names[1])
			@friends = user0_friends & user1_friends
		end
	end

	private
	def connect_to_twitter
		@client = Twitter::REST::Client.new do |config|
			# Credentials in /config/initializers/secret_token.rb
			config.consumer_key        = Rails.configuration.twitter_consumer_key
			config.consumer_secret     = Rails.configuration.twitter_consumer_secret
			config.access_token        = Rails.configuration.twitter_access_token
			config.access_token_secret = Rails.configuration.twitter_access_token_secret
    end
	end

	# Helper function to get the 20 most recent tweets for a user
	# and fetches tweets if necessary
	def get_recent_tweets(screen_name)
		# Fetch user from the database
		user = User.find_by screen_name: screen_name

		# If user not in database, create user and fetch tweets
		if user.blank?
			create(screen_name)
			update_tweets(screen_name)
		elsif user.recent_tweets.blank?
			update_tweets(screen_name)
		elsif (Time.now.utc - user.updated_at) > 600
			# Refresh recent tweets if data is older than 10 minutes
			update_tweets(screen_name)
		end

		user = User.find_by screen_name: screen_name
		return user.recent_tweets
	end 

	# Helper function to update the recent_tweets attribute for a user
	def update_tweets(screen_name)
		user = User.find_by screen_name: screen_name
		tweets = fetch_tweets(screen_name)
		user.recent_tweets = tweets 
		user.save
	end

	# Helper function to fetch the 20 most recent tweets from Twitter
	def fetch_tweets(screen_name)
		if @client.blank?
			connect_to_twitter
		end
		tweets = @client.user_timeline(screen_name)
		tweet_texts = tweets.collect{|tweet| tweet.text}
		return tweet_texts
	end

	# Helper function to get the list of friends for a user
	# and fetches friends data if necessary
	def get_friends(screen_name)
		user = User.find_by screen_name: screen_name
		if user.blank?
			create(screen_name)
			update_friends(screen_name)
		elsif user.friends.blank?
			update_friends(screen_name)
		elsif (Time.now.utc - user.updated_at) > 604800
			# Refresh friends if data is older than 1 week
			update_friends(screen_name)
		end
		user = User.find_by screen_name: screen_name
		return user.friends
	end 

	# Helper function to update the friends attribute for a user
	def update_friends(screen_name)
		user = User.find_by screen_name: screen_name
		friends = fetch_friends(screen_name)
		user.friends = friends 
		user.save
	end

	# Helper function to fetch the list of a user's friends from Twitter
	def fetch_friends(screen_name)
		if @client.blank?
			connect_to_twitter
		end
		update_tweets(screen_name)

		# Rate limiting technique from Examples
		# https://github.com/sferik/twitter/blob/master/examples/RateLimiting.md
		max_attempts = 3
		num_attempts = 0
		begin
			num_attempts += 1
			# Fails with "Rate limit exceeded" or "execution expired" for users
			# with more than a couple hundred friends
			friends = @client.friends(screen_name).to_a
		rescue Twitter::Error::TooManyRequests => error
			if num_attempts <= max_attempts
				# NOTE: Your process could go to sleep for up to 15 minutes but if you
				# retry any sooner, it will almost certainly fail with the same exception.
					sleep error.rate_limit.reset_in
				retry
			else
				raise
			end
		end

		# Filter out only the screen_name attribute
		friends_array = friends.collect{|user| user.screen_name}
		return friends_array
	end
end
