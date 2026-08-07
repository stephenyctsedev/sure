module Sure
  class << self
    def version
      Semver.new(semver)
    end

    def commit_sha
      if Rails.env.production?
        ENV["BUILD_COMMIT_SHA"]
      else
        `git rev-parse HEAD`.chomp
      end
    rescue Errno::ENOENT
      nil
    end

    private
      # `.sure-version` is the single source of truth and is written by the
      # "Release version number" workflow. The literals below are only a last
      # resort for when that file is missing, so they may lag behind.
      def semver
        stripped_content = Rails.root.join(".sure-version").read.strip
        stripped_content.presence || "0.7.4.4-fix2"
      rescue Errno::ENOENT
        "0.7.4.4-fix2"
      end
  end
end
