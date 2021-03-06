#
# A view model which backs the composite list of contributors and their
# associated accounts.
#
class ContributorList
  #
  # Initializes a new +ContributorList+, which finds all +Accounts+ for the
  # users.
  #
  # @param users - The users to initialize the +ContributorList+ with
  #
  #   ContributorList.new(User.all)
  #
  def initialize(users)
    @users = users
    accounts = Account.where(user_id: @users.map(&:id)).to_a.group_by(&:provider)
    @github_accounts = Array(accounts['github'])
  end

  #
  # Iterates through each +User+ in the +ContributorList+ and yields that
  # user's GitHub accounts.
  #
  # @yieldparam user [User]
  # @yieldparam github_accounts [Array<Account>]
  #
  #   ContributorList.new(User.all).each do |user, chef_account, github_accounts|
  #     user.chef_account == chef_account
  #     user.accounts.for('github').to_a == github_accounts
  #   end
  #
  def each
    @users.each do |user|
      # chef_account = @chef_accounts.find do |account|
      #   account.user_id == user.id
      # end

      github_account = @github_accounts.find do |account|
        account.user_id == user.id
      end

      yield user, github_account
    end
  end
end
