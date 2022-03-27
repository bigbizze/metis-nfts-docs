# metis-nfts

____

### changes from refactor of first version:
`MoreMissilesPlz.sol` has been removed, we now primarily deal with the `UfoInvasion.sol` contract, and
`MissileMaker.sol` contract, but also the `WorldLeader.sol` contract when it comes to the Biden / Putin NFTs.

----

## Latest Rinkeby Contract Addresses
> WorldLeader:
`0x8D62dE094F5a50434322D25766BDbe7a7Fbfa40e`
>
> MissileMaker
> `0x181b6345E8d71Ab8D1436041Db0B06a4376c8CfE`
> 
> UfoInvasion:
`0x8df9DfA4Db89e3fB2e3AFb84128FbE0b69E6E284`

----

## Intro

----
initialize the contract like
```ts
// typescript
const worldLeaderContract = new web3.eth.Contract(
  worldLeaderAbi.abi as any,
  worldLeaderAddress
);
const missileMakerContract = new web3.eth.Contract(
  missileMakerAbi.abi as any,
  missileMakerAddress
);
const ufoInvasionContract = new web3.eth.Contract(
  ufoInvasionContract.abi as any,
  ufoInvsaionAddress
);
```

----

## WorldLeader.sol & Minting

----

mint new NFTs like this:

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

## MissileMaker.sol & Rolling for missiles

----

```solidity
// solidity
function maybeGetMissiles(uint randVal) external;
```

```ts
// typescript

const numMissilesReadyToRoll = await missileMakerContract.methods.numMissilesReadyToRoll()
  .call({ from: walletAddress, value: "0x00" });
      
if (numMissilesReadyToRoll > 0) {
    const maybeGetMissileMethod = missileMakerContract.methods.maybeGetMissiles(getRandomInt(1, 100000));
    const receipt = await maybeGetMissileMethod
      .send({
        from: walletAddress,
        to: missileMakerAddress,
        gas: await maybeGetNukeMethod.estimateGas(),
        nonce: await web3.eth.getTransactionCount(walletAddress, "pending"),
        chainId: 1088
      });
}
```
----

```solidity
// solidity
event MissilesCreated(uint missileCreatedEventId, address createdForAddress);
```

The `MissilesCreated` event on `MissileMaker.sol` contains a `missileCreatedEventId` prop which can be used to query more complex state.

```solidity
// solidity
struct MissileCreatedState {
    uint16 dmg;
    uint32 missileCreatedEventId;
    address owner;
    uint missileNftId;
}

function getMissileCreatedInfo(uint missileNftId) public view returns (MissileCreatedState memory);
```

```ts
// typescript
type MissileCreated = {
  dmg: number,
  missileCreatedEventId: number,
  address: string,
  missileNftId: number
};

const getMissileCreatedInfoFromEvent = async (walletAddress: string) => {
  const missilesCreatedEvents = getNamedProps(await missileMakerContract.getPastEvents("MissilesCreated", { fromBlock: 0 }))
    .filter(x => x.createdForAddress === walletAddress);
  const data: MissileCreated[] = [];
  for (const { missileCreatedEventId, createdForAddress } of missilesCreatedEvents) {
    data.push(
      await missileMakerContract.methods.getMissileCreatedInfo(missileCreatedEventId)
        .call({ from: walletAddress, value: "0x0" })
    );
  }
  return data;
};
```
----

## UfoInvasion.sol & Attacking UFOs

trying to attack a UFO before there are > 100 WorldLeader NFTs minted will fail
```solidity
//solidity
function attackRandomUFOs(uint randVal, uint[] memory missileIds, uint amountUFOs) external;
```

attack `amountUFOs` random UFOs using `missileIds` missiles (max is 5 missiles)
```ts
// get all the missiles the user owns (this might be better as the user selecting which ones to use themselves)
const userMissiles = (await missileMakerContract.methods.getUserMissiles(walletAddress)
  .call({ from: walletAddress, value: "0x00" }))
  .map((x: string) => Number(x));
  
const attackRandomUfoMethod = missileMakerContract.methods.attackRandomUFOs(
  getRandomInt(1, 1000),
  userMissiles.slice(0, 4), // first 5 missiles
  3 // amountOfUFOs 
);

const receipt = await attackRandomUfoMethod
  .send({
    from: walletAddress,
    to: missileMakerAddress,
    gas: await attackRandomUfoMethod.estimateGas(),
    nonce: await web3.eth.getTransactionCount(walletAddress, "pending"),
    chainId: 1088
  });

```

----

Start a new UFO invasion game (this should be called by a client when they receive a GameOver) event
don't worry about multiple clients calling it at the same time, `_gameActive` acts as a mutex for ensuring
it's only called once at a time. The player who starts the game will be given 5% of the total UFO HP of the game
they created as score as a reward for paying to start the game.

```solidity
// solidity
function startNewUfoInvasionGame(uint randVal) public;
```

```ts
// typescript
const isGameActive = await ufoInvasionContract.methods.isGameActive()
  .call({ from: walletAddress, value: "0x0" });

if (!isGameActive) {
    const startNewUfoInvasionGameMethod = ufoInvasionContract.methods.startNewUfoInvasionGame(getRandomInt(1, 10000));
    const receipt = await startNewUfoInvasionGameMethod
      .send({
        from: walletAddress,
        to: ufoInvasionContract,
        gas: await startNewUfoInvasionGameMethod.estimateGas(),
        nonce: await web3.eth.getTransactionCount(walletAddress, "pending"),
        chainId: 1088
      });
}
```
----

The `MissileAttackedUFO` event contains a `missileTxnId` prop which will be the same for missiles used within 
the same txn, and the other two are self-explanatory. 


```solidity
// solidity

event MissileAttackedUFO(uint missileTxnId, uint missileId, address attacker);
```

You can use the `missileId` given by this event with the `getMissileAttackInfo` method on `UfoInvasion.sol` to
query more complex state about the missile attack event.

```solidity
// solidity
struct MissileAttack {
    uint16 dmg;
    uint16 hpBefore;
    uint16 hpAfter;
    uint32 missileTxnId;
    address attacker;
    address locationAddress;
    uint missileId;
    uint ufoId;
}

function getMissileAttackInfo(uint missileTxnId, uint missileId) public view returns (MissileAttack memory);
```

```ts

type MissileAttack = {
  missileTxnId: number,
  missileId: number,
  ufoId: number,
  attacker: string,
  dmg: number,
  hpBefore: number,
  hpAfter: number
}

export const getMissileAttackInfoFromEvent = async (walletAddress: string) => {
  // in case we only want missile attacks for a specific user, but u shud prob be subscribing to events for that anyway
  const missileAttacks = getNamedProps(await ufoInvasionContract.getPastEvents("MissileAttackedUFO", { fromBlock: 0 }))
    .filter(x => x.attacker === walletAddress);
  const data: MissileAttack[] = [];
  for (const { missileId, missileTxnId } of missileAttacks) {
    data.push(
      await ufoInvasionContract.methods.getMissileAttackInfo(missileTxnId, missileId)
        .call({ from: walletAddress, value: "0x0" })
    );
  }
  return data;
};
```

----

The `GameOver` event fires when every UFO in the game reaches 0 hp and includes just the gameNumber of the match.
```solidity
// solidity
event GameOver(uint gameNumber);
```

You can use the `gameNumber` given by this event with the `getGameStatsByGameNum` method on `UfoInvasion.sol` to
query more complex state about the game which has just finished.

```solidity
// solidity
struct GameStats {
    bool isOver;
    uint16 totalUfoHp;
    uint32 gameNum;
    address winner;
    uint gameStartTimeInSeconds;
    uint elapsedSecs;
    uint[] ufoIds;
}

function getGameStatsByGameNum(uint gameNum) public view returns (GameStats memory);
```

```ts
type GameStats = {
  gameNum: number,
  isOver: boolean,
  winner: string
  gameStartTimeInSeconds: number,
  ufoIds: number[]
};

export const getGameStatsFromGameOverEvent = async (walletAddress: string): Promise<GameStats | void> => {
  const gameOverEvents = getNamedProps(await ufoInvasionContract.getPastEvents("GameOver", { fromBlock: 0 }));
  if (gameOverEvents.length === 0 || !gameOverEvents[0].hasOwnProperty("gameNumber")) {
    return console.log("got no game over events!");
  }
  return await ufoInvasionContract.methods.getGameStatsByGameNum(gameOverEvents[0].gameNumber)
    .call({ from: walletAddress, value: "0x0" });
};
```

### NOTE
> Please refer to `README_OLD.md` for the other methods of querying game state. They are largely the same, except they use the `UfoInvasion.sol` contract or `MissileMaker.sol` contract instead of the proxy `MoreMissilePlz.sol` one.

