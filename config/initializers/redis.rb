Redis.current = Redis.new(url: "#{ENV['REDIS_URL']}/1", network_timeout: 5)