# metis-nfts

MoreMissilesPlz.sol contract is the main Contract to use for this

The only other one is WorldLeader.sol which is used for Minting.

All events are emitted with the MoreMissilesPlz contract.

## Latest Rinkeby Contract Addresses
`MoreMissilesPlz :: 0xa089c402bC4318b085EBC4eE1Fdc229Cc6eC9010`

`BidenWorldLeader :: 0x49351b3873155d02b7F866e30A65Cbe80De879F2`

## Intro
initialize the MoreMissilePlz contract like
```ts
// typescript
const moreMissilesPlzContract = new web3.eth.Contract(
    moreMissilesPlzAbi.abi as any,
    moreMissilesPlzAddress
);
```

here are some helpers for removing all of the garbage from solidity data queries and event responses:
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

const numMissilesReadyToRoll = await moreMissilesPlzContract.methods.numMissilesReadyToRoll().call({ from: address, value: "0x00" });
      
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

## Attack UFO

```solidity
// solidity
function attackUFO(uint[] memory missileId, uint ufoId) public
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
// solidity
event UfoDestroyed(uint ufoId, uint missileId, address locationAddress, address killerAddress);
```

whenever a UFO is destroyed by any player, the `UfoDestroyed` event is emitted

```ts
// typescript
const events = getNamedProps(await moreMissilesPlzContract.getPastEvents("UfoDestroyed", { fromBlock: 0 }));
console.log(events);
```

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

## starting a new game
```solidity
// solidity
function startNewUfoInvasionGame(uint randVal) public onlyOwner
```

this should probably be called when you receive a `GameOver` event

```ts
// typescript
const isGameActive = await moreMissilesPlzContract.methods.isGameActive().call({ from: wallet.address, value: "0x0" });
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

const getCurGameData = async (): Promise<CurGamePlayer[]> => {
  const idx = Number(
    await moreMissilesPlzContract.methods.getCurGameNumPlayers()
      .call({ from: wallet.address, value: "0x00" })
  );
  const data: CurGamePlayer[] = [];
  for (let i = 0; i < idx; i++) {
    data.push(
      await moreMissilesPlzContract.methods.getCurGamePlayerAtIdx(i)
        .call({ from: wallet.address, value: "0x00" })
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
const getLeaderboard = async (): Promise<LeaderboardPlayer[]> => {
  const idx = Number(
    await moreMissilesPlzContract.methods.getNumLeaderboardPlayers()
      .call({ from: wallet.address, value: "0x00" })
  );
  const data: LeaderboardPlayer[] = [];
  for (let i = 0; i < idx; i++) {
    data.push(
      await moreMissilesPlzContract.methods.getLeaderboardPlayerAtIdx(i)
        .call({ from: wallet.address, value: "0x00" })
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
  address: string
): Promise<GameUfo[]> => {
  const curGameNumUFOs = Number(
    await ufoInvasionContract.methods.getCurGameNumUFOs()
      .call({ from: address, value: "0x00" })
  );
  const data: GameUfo[] = [];
  for (let i = 0; i < curGameNumUFOs; i++) {
    data.push(
      await ufoInvasionContract.methods.getUfoAtIdx(i)
        .call({ from: address, value: "0x00" })
    )
  }
  return getNamedProps(data);
};

// #####################################################

```
