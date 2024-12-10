Deployment of the contract in BASE mainnet: 0x1861859FEBA682a7EF012259cD6f7d61810cE962

https://remix.ethereum.org/

1. Create PepeIsDead.sol under /contracts (left click)
2. Paste contract and sabe
3. Click Solidity Compiler (left tab) -> Compile PepeIsDead.sol
4. Click Deploy and run transaction (under Solidity Compiler button)
5. 	Environment-> Injected provider, connect your wallet under base network so you see Custom (8453) network
	Account-> Select your address
	At Address-> 0x1861859FEBA682a7EF012259cD6f7d61810cE962
6. Click At Address blue button
7. Contract will appear under deployed contracts with all its methods


== Administration methods PepeisDead Game Smart Contract (callable by Owner) ==

LOAD REWARDS - parameters: amount of PID tokens (number)
Load $PID tokens to the contract to be distributed as rewards
IMPORTANT: The tokens must be approved in the token contract BEFORE executing this!!
	https://basescan.org/address/0xcf9843ee1b84db7d3c3fdf981c0025c30d021ab6#writeContract
	Execute 1.approve with spender 0x1861859FEBA682a7EF012259cD6f7d61810cE962 and amount + 18 zeroes
	For example: If I want to load 1000 $PID I Will approve 1000000000000000000000 and then execute loadRewards with 1000


CLOSE WEEK AND DISTRIBUTE REWARDS - No parameters
This method ends a new week and put rewards available to claim with a fixed algorithm

START NEW WEEK - No parameters
This method HAS tu be executed AFTER close week. Starts new week and restarts weekly leaderboard

BAN / UNBAN WALLET - parameters: wallet addres

UPDATE TOTAL LEVELS - parameters: new total levels (number) default 13
Update number of total levels

UPDATE REWARDED WALLETS COUNT - parameters: number of wallets (number) default 20
Update number of wallets rewarded each week

TRANSFER OWNERSHIP parameters: wallet addres
If want to tranfer control of the contract to another wallet

!! RENOUNCE OWNERSHIP MUST NOT BE CALLED !!

== Game methods (callable by anyone) ==

WITHDRAW REWARD - No parameters
Will send to the wallet calling its own reward if there is any available

UPDATE SCORE- score (number), time (number seconds), levelsCompleted (number)
Uploads new score and updates leaderboards


Other read methods that give information about the data in the contract: scores, leaderboards, rewards


