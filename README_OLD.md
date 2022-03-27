# metis-nfts

----

## Latest Rinkeby Contract Addresses
> MoreMissilesPlz:
`0xf86f5c8E6F57BcC5B04D24F87188aD59b45EA2C7`

> LeaderStore
`0x7D20722366616B87368B7949136f39963554F256`

> BidenWorldLeader:
`0x3B5791eFF72127E68672Fd2e66F440Da0c4C702d`

----

## Intro

----

initialize the MoreMissilePlz contract like
```ts
// typescript
const moreMissilesPlzContract = new web3.eth.Contract(
    moreMissilesPlzAbi.abi as any,
    moreMissilesPlzAddress
);
```

here are some helpers for removing all the garbage from solidity data queries and event responses:
```ts
// typescript
const getNamedValsFromObj = <T>(obj: T): T =>
  Object.assign({}, ...Object.entries(obj)
    .filter(([key,]) => Number.isNaN(Number(key)))
    .map(([key, val]) => ({[key]: (typeof val === "string" && !val.startsWith("0x") && !Number.isNaN(Number(val)) ? Number(val) : val)}))
  )

type HasReturnValsProp<T> = { returnValues: T };

const hasReturnVals = <T>(obj: T | HasReturnValsProp<T>): obj is HasReturnValsProp<T> =>
  (obj as any).hasOwnProperty("returnValues");

const getNamedProps = <T>(events: T[] | HasReturnValsProp<T>[]) =>
  events.map(x => hasReturnVals(x) ? x.returnValues : x).map(getNamedValsFromObj);
```
----
### General Methods

----
Changing the release status
```ts
export enum ReleaseStatus {
  Unreleased,
  Whitelisted,
  Released
}

export const setReleaseStatus = async (releaseStatus: ReleaseStatus) => {
  const prevReleaseStatus = await worldLeaderContract.methods.getReleaseStatus()
    .call({ from: wallet.address, value: "0x0" });
  if (prevReleaseStatus != releaseStatus) {
    console.log(`\n\nchanging release status from ${ReleaseStatus[prevReleaseStatus]} to ${ReleaseStatus[releaseStatus]}..`);
    return await txnSender({
      method: worldLeaderContract.methods.setReleaseStatus(releaseStatus),
      contractAddress: WorldLeader
    });
  }
};
```

----
## Minting & WorldLeader Methods

----

```solidity
// solidity
function getWorldLeaderMintContract(string memory leaderName) public view returns (address);
```

this method returns the contract address for the WorldLeader by name. you can use this to mint NFTs for a specific world leader collection like this:

```ts
// typescript
const worldLeaderMintAddress = await moreMissilesPlzContract.methods.getWorldLeaderMintContract("Biden")
  .call({ from: walletAddress, value: "0x0" });

const worldLeaderMintContract = new web3.eth.Contract(
    worldLeaderAbi.abi as any,
    worldLeaderMintAddress
);
```

then you can mint new NFTs using this like this:

```ts

const mintNftMethod = worldLeaderMintContract.methods.mintNFTs(amountToMint);

const receipt = await mintNftMethod
  .send({
    from: walletAddress,
    to: worldLeaderMintAddress,
    gas: await mintNftMethod.estimateGas(),
    nonce: await web3.eth.getTransactionCount(walletAddress, "pending"),
    chainId: 1088
  });
```

you can check the status of the release like this:

```ts
enum ReleaseStatus {
  Unreleased,
  Whitelisted,
  Released
}

const curReleaseStatus = await worldLeaderMintContract.methods.getReleaseStatus()
  .call({ from: walletAddress, value: "0x0" });

if (curReleaseStatus === ReleaseStatus.Whitelisted) {
  // ..
}

```
----

## Rolling Missiles

----

```solidity
// solidity
function maybeGetMissiles(uint randVal) public;
```

```ts
// typescript
const maybeGetMissileMethod = moreMissilesPlzContract.methods.maybeGetMissiles(getRandomInt(1, 100000))

const numMissilesReadyToRoll = await moreMissilesPlzContract.methods.numMissilesReadyToRoll().call({ from: walletAddress, value: "0x00" });
      
if (numMissilesReadyToRoll > 0) {
    const receipt = await maybeGetMissileMethod
      .send({
        from: walletAddress,
        to: moreMissilesPlzAddress,
        gas: await maybeGetNukeMethod.estimateGas(),
        nonce: await web3.eth.getTransactionCount(walletAddress, "pending"),
        chainId: 1088
      });
}
```

----

when a missile is created, it emites the `MissileCreated` event

```solidity
  // solidity
  event MissileCreated(address owner, uint[] leaderNftIds, uint missileNftId, uint damage);
```

```ts
// typescript
const events = getNamedProps(await moreMissilesPlzContract.getPastEvents("MissileCreated", { fromBlock: 0 }));
console.log(events);
```

----

## Attack UFO

----

### Attack Random UFOs

attack `amountUFOs` random UFOs using `missileIds` missiles (max is 5 missiles)

```solidity
function attackRandomUFOs(uint randVal, uint[] memory missileIds, uint amountUFOs) public;
```

```ts
// get all the missiles the user owns (this might be better as the user selecting which ones to use themselves)
const userMissiles = (await moreMissilesPlzContract.methods.getUserMissiles(walletAddress)
  .call({ from: walletAddress, value: "0x00" }))
  .map((x: string) => Number(x));
  
const attackRandomUfoMethod = moreMissilesPlzContract.methods.attackRandomUFOs(
  getRandomInt(1, 1000),
  userMissiles.slice(0, 4), // first 5 missiles
  3 // amountOfUFOs 
);

const receipt = await attackRandomUfoMethod
  .send({
    from: walletAddress,
    to: moreMissilesPlzAddress,
    gas: await attackRandomUfoMethod.estimateGas(),
    nonce: await web3.eth.getTransactionCount(walletAddress, "pending"),
    chainId: 1088
  });

```
---
### Attack one UFO with multiple missiles:
```solidity
// solidity
function attackUFO(uint[] memory missileId, uint ufoId) public;
```

```ts
// typescript

// get the number of UFOs in the current game
const curGameNumUFOs = Number(
  await moreMissilesPlzContract.methods.getCurGameNumUFOs()
    .call({ from: walletAddress, value: "0x00" })
);

// get all the missiles the user owns (this might be better as the user selecting which ones to use themselves)
const userMissiles = (await moreMissilesPlzContract.methods.getUserMissiles(walletAddress)
  .call({ from: walletAddress, value: "0x00" }))
  .map((x: string) => Number(x));

// the address of the person who was randomly airdropped a UFO for this match
const ufoId = gameUfosBefore[0].ufoId;
  
const attackUfoMethod = moreMissilesPlzContract.methods.attackUFO(userMissiles, ufoId);
const receipt = await attackUfoMethod
  .send({
    from: walletAddress,
    to: moreMissilesPlzAddress,
    gas: await attackUfoMethod.estimateGas(),
    nonce: await web3.eth.getTransactionCount(walletAddress, "pending"),
    chainId: 1088
  });
```

```solidity
event MissileAttackedUFO(uint missileAttackId, address attacker, uint missileId, uint ufoId, address locationAddress, uint dmg, uint hpBefore, uint hpAfter);
```

whenever a UFO is damaged by a player, the `MissileAttackedUFO` event is emitted. subsequent attacks within the same
txn will share the same `missileAttackId`

```ts
// typescript
const events = getNamedProps(await moreMissilesPlzContract.getPastEvents("UfoDestroyed", { fromBlock: 0 }));
console.log(events);
```

---

```solidity
// solidity
event UfoDestroyed(uint ufoId, uint missileId, address locationAddress, address killerAddress);
```

whenever a UFO is destroyed by any player, the `UfoDestroyed` event is emitted

```ts
// typescript
const events = getNamedProps(await moreMissilesPlzContract.getPastEvents("UfoDestroyed", { fromBlock: 0 }));
console.log(events);
```

---

```solidity
// solidity
    
event GameOver(uint gameNumber, uint totalUfoHp, uint[] ufoIds, address winner, uint gameLengthinSeconds, uint gameStartTimeinSeconds);
```

whenever a match is finished (every UFO has 0 health left), the `GameOver` event is emitted


```ts
// typescript
const events = getNamedProps(await moreMissilesPlzContract.getPastEvents("GameOver", { fromBlock: 0 }));
console.log(events);
```

---

## ~~starting a new game~~
###THIS IS NO LONGER NECESSARY, GAME WILL AUTO START
```solidity
// solidity

event NewGame(uint gameNum, address[] locations, uint totalUfoHp,uint gameStartTimeInSeconds);
```

~~whenever a match is finished (every UFO has 0 health left), the `GameOver` event is emitted~~


```ts
// typescript
const events = getNamedProps(await moreMissilesPlzContract.getPastEvents("NewGame", { fromBlock: 0 }));
console.log(events);
```

```solidity
// solidity
function startNewUfoInvasionGame(uint randVal) public onlyOwner;
```

~~this should probably be called when you receive a `GameOver` event~~

```ts
// typescript
const isGameActive = await moreMissilesPlzContract.methods.isGameActive().call({ from: walletAddress, value: "0x0" });
const startNewUfoInvasionGameMethod = moreMissilesPlzContract.methods.startNewUfoInvasionGame(getRandomInt(1, 10000));
if (!isGameActive) {
    const receipt = await startNewUfoInvasionGameMethod
      .send({
        from: walletAddress,
        to: moreMissilesPlzAddress,
        gas: await startNewUfoInvasionGameMethod.estimateGas(),
        nonce: await web3.eth.getTransactionCount(walletAddress, "pending"),
        chainId: 1088
      });
}

```

---
## General Methods for Querying State
```solidity
// solidity
function isGameActive() public view returns (bool) {
    return _gameActive;
}

function getUserMissiles(address userAddr) external view returns (uint[] memory) {
    return tokensOfOwner(userAddr);
}

// functions for getting data about the ufo invasion game state
//

function getGameStartTime() public view returns (uint) {
    return _gameStartTime;
}

function getCurGameNumUFOs() external view returns (uint) {
    return _numUfosInGame;
}

function getUfoAtIdx(uint idx) external view returns (UfoState memory) {
    require(idx < _curUFOs.length, "there are not that many ufos in the current game!");
    return _curUFOs[idx];
}

function getCurGameNumPlayers() external view returns (uint) {
    return _numPlayersWithScoreInGame;
}

function getCurGamePlayerAtIdx(uint idx) external view returns (CurGameScore memory) {
    require(idx < _curGameAddresses.length, "there is no leaderboard entry at this index!");
    require(_curGamePlayerScoreLookup[_curGameAddresses[idx]].active, "this player has not yet played the current game!");
    return _curGamePlayerScoreLookup[_curGameAddresses[idx]];
}

function getNumLeaderboardPlayers() external view returns (uint) {
    return _numPlayersOnLeaderboard;
}

function getLeaderboardPlayerAtIdx(uint idx) external view returns (AllTimeLeaderboard memory) {
    require(idx < _allTimeLeaderboardAddresses.length, "there is no leaderboard entry at this index!");
    require(_allTimeLeaderboardLookup[_allTimeLeaderboardAddresses[idx]].exists, "this player has never scored any points before!");
    return _allTimeLeaderboardLookup[_allTimeLeaderboardAddresses[idx]];
}

function getTotalNumberOfGames() public view returns (uint) {
    return _totalNumGamesPlayed;
}

function getGameStatsByGameIdx(uint idx) public view returns (GameStats memory) {
    require(idx < _gameStats.length, "there have no been that many games yet!");
    return _gameStats[idx];
}
```

most of these are meant to be used by querying the total number of items in an array, meaning u can iterate up to this number, and use the index of your loop to then query an array item or mapping with more complex state.

getting data about the game:

```ts
// typescript

// #####################################################

type CurGamePlayer = {
  playerAddress: string,
  score: number,
  nukesUsed: number,
  active: number
};

const getCurGameData = async (
    walletAddress: string
): Promise<CurGamePlayer[]> => {
  const idx = Number(
    await moreMissilesPlzContract.methods.getCurGameNumPlayers()
      .call({ from: walletAddress, value: "0x00" })
  );
  const data: CurGamePlayer[] = [];
  for (let i = 0; i < idx; i++) {
    data.push(
      await moreMissilesPlzContract.methods.getCurGamePlayerAtIdx(i)
        .call({ from: walletAddress, value: "0x00" })
    )
  }
  return getNamedProps(data);
};

// #####################################################

type LeaderboardPlayer = {
  playerAddress: string,
  score: number,
  wins: number,
  nukesUsed: number,
  exists: boolean
};
const getLeaderboard = async (
    walletAddress: string
): Promise<LeaderboardPlayer[]> => {
  const idx = Number(
    await moreMissilesPlzContract.methods.getNumLeaderboardPlayers()
      .call({ from: walletAddress, value: "0x00" })
  );
  const data: LeaderboardPlayer[] = [];
  for (let i = 0; i < idx; i++) {
    data.push(
      await moreMissilesPlzContract.methods.getLeaderboardPlayerAtIdx(i)
        .call({ from: walletAddress, value: "0x00" })
    )
  }
  return getNamedProps(data);
};

// #####################################################

type GameUfo = {
  locationAddress: string,
  ufoId: number,
  curHp: number,
  startingHp: number
};
const getGameUfos = async (
  walletAddress: string
): Promise<GameUfo[]> => {
  const curGameNumUFOs = Number(
    await ufoInvasionContract.methods.getCurGameNumUFOs()
      .call({ from: walletAddress, value: "0x00" })
  );
  const data: GameUfo[] = [];
  for (let i = 0; i < curGameNumUFOs; i++) {
    data.push(
      await ufoInvasionContract.methods.getUfoAtIdx(i)
        .call({ from: walletAddress, value: "0x00" })
    )
  }
  return getNamedProps(data);
};

// #####################################################

```