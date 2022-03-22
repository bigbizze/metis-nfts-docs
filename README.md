# metis-nfts

MoreMissilesPlz.sol contract is the main Contract to use for this

The only other one is WorldLeader.sol which is used for Minting.

## Intro
initialize the MoreMissilePlz contract like
```ts
// typescript
const moreMissilesPlzContract = new web3.eth.Contract(
    moreMissilesPlzAbi.abi as any,
    moreMissilesPlzAddress
);
```

## Minting
```solidity
// solidity
function getWorldLeaderMintContract(string memory leaderName) public view returns (address)
```

this method returns the contract address for the WorldLeader by name. you can use this to mint NFTs for a specific world leader collection like this:

```ts
// typescript
const worldLeaderMintAddress = await moreMissilesPlzContract.methods.getWorldLeaderMintContract("Biden")
  .call({ from: wallet.address, value: "0x0" });

const worldLeaderMintContract = new web3.eth.Contract(
    worldLeaderAbi.abi as any,
    worldLeaderMintAddress
);

const mintNftMethod = contract.methods.mintNFTs(amountToMint);

const receipt = await mintNftMethod
  .send({
    from: walletAddress,
    to: worldLeaderMintAddress,
    gas: await mintNftMethod.estimateGas(),
    nonce: await web3.eth.getTransactionCount(walletAddress, "pending"),
    chainId: 1088
  });
```

## Rolling Missiles
```solidity
// solidity
function maybeGetMissiles(uint randVal) public
```

```ts
// typescript
const maybeGetMissileMethod = moreMissilesPlzContract.methods.maybeGetMissiles(getRandomInt(1, 100000))

const receipt = await maybeGetMissileMethod
  .send({
    from: walletAddress,
    to: moreMissilesPlzAddress,
    gas: await maybeGetNukeMethod.estimateGas(),
    nonce: await web3.eth.getTransactionCount(walletAddress, "pending"),
    chainId: 1088
  });
```

when a missile is created, it emites the `MissileCreated` event

```solidity
// solidity
event MissileCreated(address owner, uint[] leaderNftIds, uint missileNftId, uint damage);
```

```ts
// typescript
const events = await worldLeaderContract.getPastEvents("MissileCreated", { fromBlock: 0 });
console.log(events);
```

## Attack UFO

```solidity
// solidity
function attackUFO(uint missileId, uint ufoId) public
```

```ts
// typescript

// get the number of UFOs in the current game
const curGameNumUFOs = Number(
  await moreMissilesPlzContract.methods.getCurGameNumUFOs()
    .call({ from: address, value: "0x00" })
);

// get all the missiles the user owns (this might be better as the user selecting which ones to use themselves)
const userMissiles = (await moreMissilesPlzContract.methods.getUserMissiles(address)
  .call({ from: address, value: "0x00" }))
  .map((x: string) => Number(x));

// the NFT id of their first missile
const missileId = userMissiles[0];
// the address of the person who was randomly airdropped a UFO for this match
const ufoLocation = gameUfosBefore[0].locationAddress;
  
const attackUfoMethod = moreMissilesPlzContract.methods.attackUFO(missileId, ufoLocation);
const receipt = await attackUfoMethod
  .send({
    from: walletAddress,
    to: moreMissilesPlzAddress,
    gas: await attackUfoMethod.estimateGas(),
    nonce: await web3.eth.getTransactionCount(walletAddress, "pending"),
    chainId: 1088
  });

```solidity
// solidity
event UfoDestroyed(uint ufoId, uint missileId, address locationAddress, address killerAddress);
```

whenever a UFO is destroyed by any player, the `UfoDestroyed` event is emitted

```ts
// typescript
const events = await worldLeaderContract.getPastEvents("UfoDestroyed", { fromBlock: 0 });
console.log(events);
```

```solidity
// solidity

struct GameStats {
    uint gameNumber;
    uint totalUfoHp;
    uint numUFOs;
    address winner;
    uint gameLengthInSeconds;
    uint gameStartTimeInSeconds;
}
    
event GameOver(address winnerAddress, GameStats gameStats);
```

whenever a match is finished (every UFO has 0 health left), the `GameOver` event is emitted


```ts
// typescript
const events = await worldLeaderContract.getPastEvents("GameOver", { fromBlock: 0 });
console.log(events);
```

## starting a new game
```solidity
function startNewUfoInvasionGame(uint randVal) public onlyOwner
```
this should probably be called when you receive a `GameOver` event

```ts
const startNewUfoInvasionGameMethod = moreMissilesPlzContract.methods.startNewUfoInvasionGame(getRandomInt(1, 10000));

const receipt = await startNewUfoInvasionGameMethod
  .send({
    from: walletAddress,
    to: moreMissilesPlzAddress,
    gas: await startNewUfoInvasionGameMethod.estimateGas(),
    nonce: await web3.eth.getTransactionCount(walletAddress, "pending"),
    chainId: 1088
  });


## General Methods for Querying State
```solidity
// solidity
function getUserMissiles(address userAddr) public view returns (uint[] memory) {
    return _missileMaker.getUserMissiles(userAddr);
}

// functions for getting data about the ufo invasion game state
//

function getCurGameNumUFOs() public view returns (uint) {
    return _ufoInvasion.getCurGameNumUFOs();
}

function getUfoAtIdx(uint idx) public view returns (UfoInvasion.UfoState memory) {
    return _ufoInvasion.getUfoAtIdx(idx);
}

function getCurGameNumPlayers() public view returns (uint) {
    return _ufoInvasion.getCurGameNumPlayers();
}

function getCurGamePlayerAtIdx(uint idx) public view returns (address) {
    return _ufoInvasion.getCurGamePlayerAtIdx(idx);
}

function getCurGamePlayerScore(address playerAddr) public view returns (UfoInvasion.CurGameScore memory) {
    return _ufoInvasion.getCurGamePlayerScore(playerAddr);
}

function getNumLeaderboardPlayers() public view returns (uint) {
    return _ufoInvasion.getNumLeaderboardPlayers();
}

function getLeaderboardPlayerAtIdx(uint idx) public view returns (address) {
    return _ufoInvasion.getLeaderboardPlayerAtIdx(idx);
}

function getLeaderboardPlayerScore(address playerAddr) public view returns (UfoInvasion.AllTimeLeaderboard memory) {
    return _ufoInvasion.getLeaderboardPlayerScore(playerAddr);
}

function getTotalNumberOfGames() public view returns (uint) {
    return _ufoInvasion.getTotalNumberOfGames();
}

function getGameStatsByGameIdx(uint idx) public view returns (UfoInvasion.GameStats memory) {
    return _ufoInvasion.getGameStatsByGameIdx(idx);
}
```

most of these are meant to be used by querying the total number of items in an array, meaning u can iterate up to this number, and use the index of your loop to then query an array item or mapping with more complex state.

for e.g., to generate a list of the stats of all of the active UFOs in the current game

```ts
// typescript

type GameUfo = {
  address: string,
  ufoId: number,
  curHp: number,
  startingHp: number
};

const curGameNumUFOs = Number(
  await moreMissilesPlzContract.methods.getCurGameNumUFOs()
    .call({ from: address, value: "0x00" })
);
const gameUfos: GameUfo[] = [];
for (let i = 0; i < curGameNumUFOs; i++) {
  gameUfos.push(
    await moreMissilesPlzContract.methods.getUfoAtIdx(i)
      .call({ from: address, value: "0x00" })
  )
}
```

or for querying the all-time leaderboard data

```ts
type LeaderboardPlayer = {
  playerAddress: string,
  score: number,
  wins: number,
  nukesUsed: number,
  exists: boolean
};

const leaderBoardPlayers: LeaderboardPlayer[] = [];
for (let i = 0; i < numLeaderboardPlayers; i++) {
  leaderBoardPlayers.push(
    await moreMissilesPlzContract.methods.getLeaderboardPlayerAtIdx(i)
      .call({ from: address, value: "0x00" })
  )
}

console.log(leaderBoardPlayers);
```
