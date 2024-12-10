// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/ReentrancyGuard.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract PepeIsDead is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    IERC20 public constant REWARD_TOKEN = IERC20(0xCF9843EE1B84Db7d3c3FdF981c0025c30d021ab6);

    struct Score {
        address player;
        uint256 points;
        uint256 time;
        uint8 levelsCompleted;
        bool isComplete;
    }

    uint256 public currentWeek;
    uint256 public rewardPool;
    bool public weekClosed;
    uint8 public totalLevels = 13; // Default total levels, adjustable
    uint8 public rewardedWalletsCount = 20; // Default number of wallets rewarded per week, adjustable

    mapping(uint256 => mapping(address => Score)) public weeklyScores;
    mapping(address => Score) public allTimeScores;
    mapping(address => uint256) public allTimeTotalPoints;
    mapping(address => uint256) public rewards;
    mapping(address => bool) public bannedWallets;

    Score[] public weeklyTopPlayers;
    Score[] public allTimeTopPlayers;

    event ScoreUpdated(address indexed player, uint256 points, uint256 time, uint8 levelsCompleted, bool isComplete);
    event RewardDeposited(uint256 amount);
    event ClaimableReward(address indexed wallet, uint256 reward);
    event RewardWithdrawn(address indexed player, uint256 amount);
    event WeekClosed(uint256 week);
    event NewWeekStarted(uint256 newWeek);
    event WalletBanned(address indexed wallet);
    event WalletUnbanned(address indexed wallet);
    event TotalLevelsUpdated(uint8 newTotalLevels);
    event RewardedWalletsUpdated(uint8 newRewardedWalletsCount);
    

    constructor() Ownable(msg.sender) {
        currentWeek = 1;
    }

    modifier onlyCurrentWeek(uint256 week) {
        require(week == currentWeek, "Only updates for the current week are allowed");
        require(!weekClosed, "The current week is already closed");
        _;
    }

    modifier notBanned(address player) {
        require(!bannedWallets[player], "This wallet is banned");
        _;
    }

    function updateTotalLevels(uint8 newTotalLevels) external onlyOwner {
        require(newTotalLevels > 0, "Total levels must be greater than zero");
        totalLevels = newTotalLevels;
        emit TotalLevelsUpdated(newTotalLevels);
    }

    function updateRewardedWalletsCount(uint8 newCount) external onlyOwner {
        require(newCount > 0, "Rewarded wallets count must be greater than zero");
        rewardedWalletsCount = newCount;
        emit RewardedWalletsUpdated(newCount);
    }

    function updateScore(uint256 points, uint256 time, uint8 levelsCompleted) 
        external 
        onlyCurrentWeek(currentWeek) 
        notBanned(msg.sender) 
    {
        require(points > 0, "Points must be greater than zero");
        require(levelsCompleted > 0 && levelsCompleted <= totalLevels, "Invalid number of levels completed");

        Score storage playerScore = weeklyScores[currentWeek][msg.sender];

        bool isBetterScore = (points > playerScore.points) || 
                            (points == playerScore.points && time < playerScore.time);

        if (isBetterScore) {
            uint256 previousPoints = playerScore.points;

            playerScore.player = msg.sender;
            playerScore.points = points;
            playerScore.time = time;
            playerScore.levelsCompleted = levelsCompleted;
            playerScore.isComplete = (levelsCompleted == totalLevels);

            if (points > allTimeScores[msg.sender].points ||
                (points == allTimeScores[msg.sender].points && time < allTimeScores[msg.sender].time)) {
                allTimeScores[msg.sender] = playerScore;
            }

            if (levelsCompleted == totalLevels && points > previousPoints) {
                uint256 pointsDifference = points - previousPoints;
                allTimeTotalPoints[msg.sender] += pointsDifference;
            }

            insertTopPlayer(weeklyTopPlayers, playerScore);
            insertTopPlayer(allTimeTopPlayers, allTimeScores[msg.sender]);

            emit ScoreUpdated(msg.sender, playerScore.points, playerScore.time, playerScore.levelsCompleted, playerScore.isComplete);
        }
    }

    function insertTopPlayer(Score[] storage leaderboard, Score memory newScore) internal {
        uint256 len = leaderboard.length;
        int256 existingIndex = -1;


        for (uint256 i = 0; i < len; i++) {
            if (leaderboard[i].player == newScore.player) {
                existingIndex = int256(i);
                break;
            }
        }

        if (existingIndex >= 0) {
            uint256 index = uint256(existingIndex);
            if (newScore.points > leaderboard[index].points ||
                (newScore.points == leaderboard[index].points && newScore.time < leaderboard[index].time)) {
                leaderboard[index] = newScore; // Update the existing entry with the better score or lower time
                sortLeaderboard(leaderboard);  // Sort to maintain the order
            }
        } else {
            if (len < rewardedWalletsCount) {
                leaderboard.push(newScore);
                sortLeaderboard(leaderboard);
            } else if (newScore.points > leaderboard[len - 1].points ||
                    (newScore.points == leaderboard[len - 1].points && newScore.time < leaderboard[len - 1].time)) {
                leaderboard[len - 1] = newScore;
                sortLeaderboard(leaderboard);
            }
        }
    }

    function sortLeaderboard(Score[] storage leaderboard) internal {
        uint256 len = leaderboard.length;
        for (uint256 i = 0; i < len; i++) {
            for (uint256 j = i + 1; j < len; j++) {
                if (leaderboard[j].points > leaderboard[i].points ||
                    (leaderboard[j].points == leaderboard[i].points && leaderboard[j].time < leaderboard[i].time)) {
                    // Swap elements to maintain order
                    Score memory temp = leaderboard[i];
                    leaderboard[i] = leaderboard[j];
                    leaderboard[j] = temp;
                }
            }
        }
    }

    function loadRewards(uint256 tokens) external onlyOwner {
        uint256 amount = tokens * 10**18;
        require(amount > 0, "No rewards to load");

        REWARD_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        rewardPool += amount;

        emit RewardDeposited(amount);
    }

    function startNewWeek() external onlyOwner {
        require(weekClosed, "The current week must be closed before starting a new one");
        currentWeek += 1;
        weekClosed = false;

        delete weeklyTopPlayers;

        emit NewWeekStarted(currentWeek);
    }

    function closeWeekAndDistributeRewards() external onlyOwner {
        require(!weekClosed, "The week is already closed");
        require(rewardPool > 0, "Reward pool is empty");

        for (uint256 i = 0; i < weeklyTopPlayers.length; i++) {
            rewards[weeklyTopPlayers[i].player] = 0;
        }

        uint256 totalReward = rewardPool;
        uint256 totalDistributed = 0;

        // Distribute 12%, 8%, and 5% of the total reward to the top 3 players
        if (weeklyTopPlayers.length >= 3) {
            rewards[weeklyTopPlayers[0].player] += (totalReward * 12) / 100;
            rewards[weeklyTopPlayers[1].player] += (totalReward * 8) / 100;
            rewards[weeklyTopPlayers[2].player] += (totalReward * 5) / 100;
            emit ClaimableReward(weeklyTopPlayers[0].player, rewards[weeklyTopPlayers[0].player]);
            emit ClaimableReward(weeklyTopPlayers[1].player, rewards[weeklyTopPlayers[1].player]);
            emit ClaimableReward(weeklyTopPlayers[2].player, rewards[weeklyTopPlayers[2].player]);
            totalDistributed = (totalReward * 25) / 100;

            uint256 maxRewardPerOtherPlayer = (totalReward * 3) / 100;

            uint256 remainingReward = totalReward - totalDistributed;
            uint256 otherRewardCount = rewardedWalletsCount > 3 ? rewardedWalletsCount - 3 : 0;
            uint256 totalWeight = (otherRewardCount * (otherRewardCount + 1)) / 2;

            for (uint256 i = 3; i < weeklyTopPlayers.length && i < rewardedWalletsCount; i++) {
                uint256 position = i - 2;
                uint256 rewardAmount = (remainingReward * (otherRewardCount - position + 1)) / totalWeight;

                if (rewardAmount > maxRewardPerOtherPlayer) {
                    rewardAmount = maxRewardPerOtherPlayer;
                }

                rewards[weeklyTopPlayers[i].player] = rewardAmount;
                totalDistributed += rewardAmount;
                emit ClaimableReward(weeklyTopPlayers[i].player, rewardAmount);
            }
        } else if (weeklyTopPlayers.length == 2) {
            rewards[weeklyTopPlayers[0].player] = (totalReward * 12) / 100;
            rewards[weeklyTopPlayers[1].player] = (totalReward * 8) / 100;
            totalDistributed = (totalReward * 20) / 100;

            emit ClaimableReward(weeklyTopPlayers[0].player, rewards[weeklyTopPlayers[0].player]);
            emit ClaimableReward(weeklyTopPlayers[1].player, rewards[weeklyTopPlayers[1].player]);
        } else if (weeklyTopPlayers.length == 1) {
            rewards[weeklyTopPlayers[0].player] = (totalReward * 12) / 100;
            totalDistributed = (totalReward * 12) / 100;

            emit ClaimableReward(weeklyTopPlayers[0].player, rewards[weeklyTopPlayers[0].player]);
        }

        rewardPool -= totalDistributed;
        weekClosed = true;

        emit WeekClosed(currentWeek);
    }

    function withdrawReward() external nonReentrant notBanned(msg.sender) {
        uint256 amount = rewards[msg.sender];
        require(amount > 0, "No rewards available for withdrawal");

        rewards[msg.sender] = 0;
        require(REWARD_TOKEN.transfer(msg.sender, amount), "Token transfer failed");

        emit RewardWithdrawn(msg.sender, amount);
    }

    function banWallet(address wallet) external onlyOwner {
        require(!bannedWallets[wallet], "Wallet is already banned");
        bannedWallets[wallet] = true;
        emit WalletBanned(wallet);
    }

    function unbanWallet(address wallet) external onlyOwner {
        require(bannedWallets[wallet], "Wallet is not banned");
        bannedWallets[wallet] = false;
        emit WalletUnbanned(wallet);
    }

    function getWeeklyTopPlayers() external view returns (Score[] memory) {
        return weeklyTopPlayers;
    }

    function getAllTimeTopPlayers() external view returns (Score[] memory) {
        return allTimeTopPlayers;
    }
}
