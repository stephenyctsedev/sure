require "test_helper"

class Assistant::Function::SyncAccountsTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @family = @user.family
    @fn = Assistant::Function::SyncAccounts.new(@user)
  end

  test "to_definition returns correct schema" do
    definition = @fn.to_definition
    assert_equal "sync_accounts", definition[:name]
    assert_not_empty definition[:description]
  end

  test "enqueues a family sync and returns its id and status" do
    sync = OpenStruct.new(id: "sync-123", status: "pending")
    @user.family.expects(:sync_later).returns(sync).once

    result = @fn.call

    assert result[:success]
    assert_equal "sync-123", result[:sync_id]
    assert_equal "pending", result[:status]
  end

  test "returns a soft error when sync fails to enqueue" do
    @user.family.expects(:sync_later).raises(StandardError, "boom")

    result = @fn.call

    assert_equal false, result[:success]
    assert_equal "unexpected_error", result[:error]
  end
end
