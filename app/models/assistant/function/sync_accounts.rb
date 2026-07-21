class Assistant::Function::SyncAccounts < Assistant::Function
  class << self
    def name
      "sync_accounts"
    end

    def description
      <<~INSTRUCTIONS
        Triggers a full sync of the user's family. This applies all active rules,
        syncs every linked account with its provider, and auto-matches transfers.

        Syncing runs in the background — this returns immediately with the id and
        status of the enqueued sync rather than waiting for it to finish. If a recent
        sync is already in progress, its id is returned instead of starting a new one.
      INSTRUCTIONS
    end
  end

  def call(params = {})
    sync = family.sync_later

    {
      success: true,
      sync_id: sync.id,
      status: sync.status,
      message: "Sync enqueued. It will run in the background."
    }
  rescue => e
    { success: false, error: "unexpected_error", message: e.message }
  end
end
