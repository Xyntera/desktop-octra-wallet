# Streamflow Wallet Monitor & Auto-Sniper Bot - Targeted Workflow

## Overview
This bot monitors a **specific wallet address** for Streamflow token lock transactions on Solana and instantly buys the locked tokens based on market cap criteria. By tracking a trusted wallet that consistently locks tokens via Streamflow, we can snipe legitimate projects with reduced rug risk.

**Target Wallet:** `B743wFVk2pCYhV91cn287e1xY7f1vt4gdY48hhNiuQmT`

---

## System Architecture

```
Wallet Monitor → Lock Detection → Parse Token → Market Cap Check → Validation → Instant Buy
      ↓               ↓              ↓               ↓               ↓            ↓
  WebSocket/     Streamflow      Extract Mint   DexScreener API  Safety Check  DEX Execute
   Poll Tx       Program ID                                                      
```

---

## Key Differences from Generic Monitor

### Standard Streamflow Bot:
- Monitors ALL Streamflow lock events globally
- High noise, many false positives
- Slower reaction time

### Wallet-Targeted Sniper (This Bot):
- ✅ Monitors **ONE specific wallet** only
- ✅ Filters for Streamflow locks from this wallet
- ✅ Much faster detection and execution
- ✅ Focuses on trusted source
- ✅ Market cap validation before buying

---

## Phase 1: Environment Setup

### Prerequisites
- Node.js 18+ or Python 3.9+
- Solana wallet with SOL for gas + trading capital
- Premium RPC endpoint (Helius/QuickNode recommended for speed)
- DexScreener API access (for market cap data)
- Private key stored securely

### Required Libraries

**TypeScript/JavaScript:**
```bash
npm install @solana/web3.js @solana/spl-token
npm install @project-serum/anchor
npm install @raydium-io/raydium-sdk
npm install bs58 dotenv axios
npm install @coral-xyz/anchor
```

**Python:**
```bash
pip install solana anchorpy solders base58 python-dotenv requests aiohttp
```

### Environment Variables
```env
# RPC Configuration
RPC_ENDPOINT=https://your-premium-rpc.com
RPC_WEBSOCKET=wss://your-premium-rpc.com
PRIVATE_KEY=your_base58_private_key

# Target Configuration
TARGET_WALLET=B743wFVk2pCYhV91cn287e1xY7f1vt4gdY48hhNiuQmT
STREAMFLOW_PROGRAM_ID=strmRqUCoQUgGUan5YhzUZa6KqdzwX5L6FpUxfmKg5m

# Market Cap Thresholds (in USD)
MIN_MARKET_CAP=10000
MAX_MARKET_CAP=500000

# Trading Configuration
BUY_AMOUNT_SOL=0.1
MAX_SLIPPAGE=8
MIN_LIQUIDITY_SOL=2
PRIORITY_FEE_MICROLAMPORTS=100000

# Safety Features
DRY_RUN=false
ENABLE_DUPLICATE_CHECK=true
COOLDOWN_BETWEEN_BUYS_MS=3000
```

---

## Phase 2: Monitor Target Wallet for Streamflow Locks

### Core Strategy
Instead of monitoring the Streamflow program globally, we monitor the **target wallet's transaction activity** and filter for Streamflow interactions.

### Implementation: WebSocket Subscription (Best for Speed)

```typescript
import { Connection, PublicKey } from '@solana/web3.js';

const TARGET_WALLET = new PublicKey('B743wFVk2pCYhV91cn287e1xY7f1vt4gdY48hhNiuQmT');
const STREAMFLOW_PROGRAM = new PublicKey('strmRqUCoQUgGUan5YhzUZa6KqdzwX5L6FpUxfmKg5m');

const connection = new Connection(process.env.RPC_ENDPOINT, {
  wsEndpoint: process.env.RPC_WEBSOCKET,
  commitment: 'confirmed'
});

// Subscribe to target wallet's transaction logs
const subscriptionId = connection.onLogs(
  TARGET_WALLET,
  async (logs, context) => {
    console.log('🔍 Transaction detected from target wallet');
    
    // Check if this transaction involves Streamflow
    const isStreamflowTx = logs.logs.some(log => 
      log.includes(STREAMFLOW_PROGRAM.toBase58())
    );
    
    if (isStreamflowTx) {
      console.log('🎯 STREAMFLOW LOCK DETECTED!');
      await handleStreamflowLock(logs.signature);
    }
  },
  'confirmed'
);

console.log(`👀 Monitoring wallet: ${TARGET_WALLET.toBase58()}`);
console.log(`📡 Subscription ID: ${subscriptionId}`);
```

### Alternative: Polling Method (Backup)

```typescript
const processedSignatures = new Set<string>();

async function pollWalletTransactions() {
  try {
    const signatures = await connection.getSignaturesForAddress(
      TARGET_WALLET,
      { limit: 5 }
    );
    
    for (const sigInfo of signatures) {
      // Skip if already processed
      if (processedSignatures.has(sigInfo.signature)) {
        continue;
      }
      
      processedSignatures.add(sigInfo.signature);
      
      // Fetch transaction details
      const tx = await connection.getParsedTransaction(
        sigInfo.signature,
        { maxSupportedTransactionVersion: 0 }
      );
      
      if (!tx) continue;
      
      // Check if Streamflow program is involved
      const accountKeys = tx.transaction.message.accountKeys;
      const hasStreamflow = accountKeys.some(
        key => key.pubkey.toBase58() === STREAMFLOW_PROGRAM.toBase58()
      );
      
      if (hasStreamflow) {
        console.log('🎯 STREAMFLOW LOCK DETECTED!');
        await handleStreamflowLock(sigInfo.signature);
      }
    }
  } catch (error) {
    console.error('Polling error:', error);
  }
}

// Poll every 2 seconds
setInterval(pollWalletTransactions, 2000);
```

### Python WebSocket Version

```python
import asyncio
from solana.rpc.websocket_api import connect
from solders.pubkey import Pubkey

TARGET_WALLET = Pubkey.from_string("B743wFVk2pCYhV91cn287e1xY7f1vt4gdY48hhNiuQmT")
STREAMFLOW_PROGRAM = Pubkey.from_string("strmRqUCoQUgGUan5YhzUZa6KqdzwX5L6FpUxfmKg5m")

async def monitor_wallet():
    async with connect(RPC_WEBSOCKET) as websocket:
        await websocket.logs_subscribe(TARGET_WALLET)
        
        first_resp = await websocket.recv()
        subscription_id = first_resp[0].result
        print(f"📡 Subscribed: {subscription_id}")
        
        async for msg in websocket:
            logs = msg[0].result.value.logs
            signature = msg[0].result.value.signature
            
            # Check for Streamflow program
            streamflow_detected = any(
                str(STREAMFLOW_PROGRAM) in log for log in logs
            )
            
            if streamflow_detected:
                print(f"🎯 STREAMFLOW LOCK: {signature}")
                await handle_streamflow_lock(signature)

asyncio.run(monitor_wallet())
```

### Debugging Checkpoint 1
- ✅ WebSocket connection established?
- ✅ Receiving logs from target wallet?
- ✅ Can detect Streamflow program involvement?
- ✅ Getting transaction signatures correctly?

**Test Command:**
```bash
# Check recent transactions from target wallet
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSignaturesForAddress","params":["B743wFVk2pCYhV91cn287e1xY7f1vt4gdY48hhNiuQmT",{"limit":5}]}' \
  YOUR_RPC_ENDPOINT
```

---

## Phase 3: Parse Lock Transaction & Extract Token

### Goal
When a Streamflow lock is detected, extract:
1. **Token Mint Address** (what token is being locked)
2. **Lock Amount** (how much)
3. **Lock Duration** (vesting schedule)
4. **Timestamp**

### TypeScript Implementation

```typescript
import { ParsedTransactionWithMeta } from '@solana/web3.js';

interface StreamflowLockData {
  tokenMint: string;
  lockedAmount: number;
  timestamp: number;
  signature: string;
  sender: string;
}

async function handleStreamflowLock(signature: string): Promise<void> {
  try {
    const lockData = await parseStreamflowTransaction(signature);
    
    if (!lockData) {
      console.log('❌ Could not parse lock data');
      return;
    }
    
    console.log('📦 Lock Details:', {
      token: lockData.tokenMint,
      amount: lockData.lockedAmount,
      time: new Date(lockData.timestamp * 1000).toISOString()
    });
    
    // Proceed to validation and buying
    await processTokenBuy(lockData);
    
  } catch (error) {
    console.error('Error handling lock:', error);
  }
}

async function parseStreamflowTransaction(
  signature: string
): Promise<StreamflowLockData | null> {
  
  const tx = await connection.getParsedTransaction(signature, {
    maxSupportedTransactionVersion: 0,
    commitment: 'confirmed'
  });
  
  if (!tx || !tx.meta) {
    throw new Error('Transaction not found');
  }
  
  // Method 1: Check post token balances
  const postTokenBalances = tx.meta.postTokenBalances || [];
  const preTokenBalances = tx.meta.preTokenBalances || [];
  
  let tokenMint: string | null = null;
  let lockedAmount = 0;
  
  // Find token that increased in Streamflow-controlled account
  for (const postBalance of postTokenBalances) {
    const preBalance = preTokenBalances.find(
      pre => pre.accountIndex === postBalance.accountIndex
    );
    
    const preAmount = preBalance?.uiTokenAmount?.uiAmount || 0;
    const postAmount = postBalance.uiTokenAmount?.uiAmount || 0;
    
    // Locked amount is the increase
    if (postAmount > preAmount) {
      tokenMint = postBalance.mint;
      lockedAmount = postAmount - preAmount;
      break;
    }
  }
  
  // Method 2: Parse instruction data (backup)
  if (!tokenMint) {
    const instructions = tx.transaction.message.instructions;
    
    for (const ix of instructions) {
      if ('parsed' in ix && ix.program === 'spl-token') {
        if (ix.parsed.type === 'transfer') {
          const info = ix.parsed.info;
          // Additional logic to identify the locked token
          // This varies based on Streamflow's exact implementation
        }
      }
    }
  }
  
  if (!tokenMint) {
    return null;
  }
  
  return {
    tokenMint,
    lockedAmount,
    timestamp: tx.blockTime || Math.floor(Date.now() / 1000),
    signature,
    sender: TARGET_WALLET.toBase58()
  };
}
```

### Python Version

```python
from solana.rpc.api import Client
from solders.signature import Signature

async def parse_streamflow_transaction(signature: str) -> dict:
    client = Client(RPC_ENDPOINT)
    
    tx = client.get_transaction(
        Signature.from_string(signature),
        encoding="jsonParsed",
        max_supported_transaction_version=0
    )
    
    if not tx.value:
        raise Exception("Transaction not found")
    
    meta = tx.value.transaction.meta
    post_balances = meta.post_token_balances or []
    pre_balances = meta.pre_token_balances or []
    
    # Find token with increased balance
    for post_bal in post_balances:
        pre_bal = next(
            (p for p in pre_balances if p.account_index == post_bal.account_index),
            None
        )
        
        pre_amount = pre_bal.ui_token_amount.ui_amount if pre_bal else 0
        post_amount = post_bal.ui_token_amount.ui_amount
        
        if post_amount > pre_amount:
            return {
                'token_mint': post_bal.mint,
                'locked_amount': post_amount - pre_amount,
                'timestamp': tx.value.block_time,
                'signature': signature
            }
    
    return None
```

### Debugging Checkpoint 2
- ✅ Parsing transaction correctly?
- ✅ Extracting correct token mint?
- ✅ Getting accurate locked amount?
- ✅ Handling transactions with multiple tokens?

---

## Phase 4: Market Cap Validation

### Why Market Cap Matters
- Too low (<$10k): Likely too early, high rug risk
- Too high (>$500k): Already pumped, less upside
- Sweet spot: $10k - $500k for sniper opportunities

### Implementation: DexScreener API

```typescript
import axios from 'axios';

interface MarketData {
  marketCap: number;
  liquidity: number;
  priceUSD: number;
  volume24h: number;
  priceChange24h: number;
}

async function getMarketCapData(tokenMint: string): Promise<MarketData | null> {
  try {
    const response = await axios.get(
      `https://api.dexscreener.com/latest/dex/tokens/${tokenMint}`,
      { timeout: 5000 }
    );
    
    if (!response.data || !response.data.pairs || response.data.pairs.length === 0) {
      console.log('⚠️ No market data found');
      return null;
    }
    
    // Get the most liquid pair
    const pairs = response.data.pairs.sort((a, b) => 
      (b.liquidity?.usd || 0) - (a.liquidity?.usd || 0)
    );
    
    const mainPair = pairs[0];
    
    return {
      marketCap: mainPair.fdv || mainPair.marketCap || 0,
      liquidity: mainPair.liquidity?.usd || 0,
      priceUSD: parseFloat(mainPair.priceUsd || '0'),
      volume24h: mainPair.volume?.h24 || 0,
      priceChange24h: mainPair.priceChange?.h24 || 0
    };
    
  } catch (error) {
    console.error('Error fetching market data:', error.message);
    return null;
  }
}

async function validateMarketCap(tokenMint: string): Promise<boolean> {
  const MIN_MC = parseFloat(process.env.MIN_MARKET_CAP || '10000');
  const MAX_MC = parseFloat(process.env.MAX_MARKET_CAP || '500000');
  const MIN_LIQ_USD = 1000; // Minimum $1k liquidity
  
  const marketData = await getMarketCapData(tokenMint);
  
  if (!marketData) {
    console.log('❌ No market data - skipping');
    return false;
  }
  
  console.log('📊 Market Data:', {
    marketCap: `$${marketData.marketCap.toLocaleString()}`,
    liquidity: `$${marketData.liquidity.toLocaleString()}`,
    price: `$${marketData.priceUSD}`,
    volume24h: `$${marketData.volume24h.toLocaleString()}`
  });
  
  // Check market cap range
  if (marketData.marketCap < MIN_MC) {
    console.log(`❌ Market cap too low: $${marketData.marketCap} < $${MIN_MC}`);
    return false;
  }
  
  if (marketData.marketCap > MAX_MC) {
    console.log(`❌ Market cap too high: $${marketData.marketCap} > $${MAX_MC}`);
    return false;
  }
  
  // Check liquidity
  if (marketData.liquidity < MIN_LIQ_USD) {
    console.log(`❌ Insufficient liquidity: $${marketData.liquidity}`);
    return false;
  }
  
  console.log('✅ Market cap validation passed!');
  return true;
}
```

### Alternative: Jupiter API for Price/Liquidity

```typescript
async function getJupiterQuote(tokenMint: string, solAmount: number) {
  const SOL_MINT = 'So11111111111111111111111111111111111111112';
  const amountLamports = solAmount * 1e9;
  
  const response = await axios.get(
    `https://quote-api.jup.ag/v6/quote`,
    {
      params: {
        inputMint: SOL_MINT,
        outputMint: tokenMint,
        amount: amountLamports,
        slippageBps: 50 // 0.5% for quote
      }
    }
  );
  
  const quote = response.data;
  const outAmount = parseInt(quote.outAmount);
  const price = amountLamports / outAmount;
  
  return {
    outAmount,
    price,
    priceImpact: quote.priceImpactPct
  };
}
```

### Debugging Checkpoint 3
- ✅ DexScreener API responding?
- ✅ Getting accurate market cap data?
- ✅ Validation logic working correctly?
- ✅ Handling tokens not yet listed?

---

## Phase 5: Additional Safety Validation

### Critical Safety Checks

```typescript
import { getMint } from '@solana/spl-token';

async function performSafetyChecks(tokenMint: string): Promise<boolean> {
  console.log('🔒 Running safety checks...');
  
  try {
    const mintPubkey = new PublicKey(tokenMint);
    const mintInfo = await getMint(connection, mintPubkey);
    
    // 1. Check mint authority
    if (mintInfo.mintAuthority !== null) {
      console.log('⚠️ WARNING: Mint authority exists - can mint more tokens!');
      // Decide if you want to skip or proceed with caution
      // return false; // Uncomment to skip
    }
    
    // 2. Check freeze authority
    if (mintInfo.freezeAuthority !== null) {
      console.log('❌ DANGER: Freeze authority exists - can freeze tokens!');
      return false; // Always skip tokens that can be frozen
    }
    
    // 3. Check supply
    const supply = Number(mintInfo.supply) / Math.pow(10, mintInfo.decimals);
    console.log(`📈 Total Supply: ${supply.toLocaleString()}`);
    
    // 4. Additional checks can be added here
    // - Top holder concentration
    // - Contract verification
    // - Social signals
    
    console.log('✅ Safety checks passed');
    return true;
    
  } catch (error) {
    console.error('Safety check error:', error);
    return false;
  }
}
```

### Top Holder Check (Advanced)

```typescript
async function checkTopHolders(tokenMint: string): Promise<boolean> {
  try {
    const mintPubkey = new PublicKey(tokenMint);
    
    // Get largest token accounts
    const largestAccounts = await connection.getTokenLargestAccounts(mintPubkey);
    
    if (largestAccounts.value.length === 0) {
      return true;
    }
    
    // Get total supply
    const mintInfo = await getMint(connection, mintPubkey);
    const totalSupply = Number(mintInfo.supply);
    
    // Check top holder percentage
    const topHolderAmount = Number(largestAccounts.value[0].amount);
    const topHolderPercent = (topHolderAmount / totalSupply) * 100;
    
    console.log(`👥 Top holder owns: ${topHolderPercent.toFixed(2)}%`);
    
    // Flag if top holder owns >20%
    if (topHolderPercent > 20) {
      console.log('⚠️ WARNING: High concentration - top holder owns >20%');
      // return false; // Uncomment to skip
    }
    
    return true;
    
  } catch (error) {
    console.error('Top holder check error:', error);
    return true; // Continue on error
  }
}
```

### Debugging Checkpoint 4
- ✅ Fetching mint info correctly?
- ✅ Detecting dangerous mint/freeze authorities?
- ✅ Top holder calculations accurate?
- ✅ All safety checks completing?

---

## Phase 6: Execute Instant Buy (Sniper Logic)

### Strategy: Speed is Critical
1. Pre-create token account if possible
2. Use high priority fees
3. Skip preflight checks for speed (risky but faster)
4. Use Jupiter aggregator for best price

### Jupiter Swap Implementation (Recommended)

```typescript
import { Connection, VersionedTransaction, PublicKey } from '@solana/web3.js';
import axios from 'axios';
import bs58 from 'bs58';

const SOL_MINT = 'So11111111111111111111111111111111111111112';

async function executeBuy(
  tokenMint: string,
  solAmount: number
): Promise<string | null> {
  
  try {
    console.log(`💰 Executing buy: ${solAmount} SOL for ${tokenMint}`);
    
    const amountLamports = Math.floor(solAmount * 1e9);
    const slippageBps = parseInt(process.env.MAX_SLIPPAGE || '8') * 100;
    
    // Step 1: Get quote from Jupiter
    console.log('📋 Getting quote...');
    const quoteResponse = await axios.get(
      'https://quote-api.jup.ag/v6/quote',
      {
        params: {
          inputMint: SOL_MINT,
          outputMint: tokenMint,
          amount: amountLamports,
          slippageBps: slippageBps,
          onlyDirectRoutes: false,
          asLegacyTransaction: false
        }
      }
    );
    
    const quote = quoteResponse.data;
    console.log(`📊 Quote: ${quote.outAmount} tokens`);
    
    // Step 2: Get swap transaction
    console.log('🔨 Building transaction...');
    const swapResponse = await axios.post(
      'https://quote-api.jup.ag/v6/swap',
      {
        quoteResponse: quote,
        userPublicKey: wallet.publicKey.toBase58(),
        wrapAndUnwrapSol: true,
        dynamicComputeUnitLimit: true,
        prioritizationFeeLamports: parseInt(
          process.env.PRIORITY_FEE_MICROLAMPORTS || '100000'
        )
      }
    );
    
    const { swapTransaction } = swapResponse.data;
    
    // Step 3: Deserialize and sign
    const swapTransactionBuf = Buffer.from(swapTransaction, 'base64');
    const transaction = VersionedTransaction.deserialize(swapTransactionBuf);
    transaction.sign([wallet]);
    
    // Step 4: Send with high priority
    console.log('🚀 Sending transaction...');
    const rawTransaction = transaction.serialize();
    
    const signature = await connection.sendRawTransaction(rawTransaction, {
      skipPreflight: true, // SPEED: Skip simulation
      maxRetries: 3,
      preflightCommitment: 'confirmed'
    });
    
    console.log(`📤 Transaction sent: ${signature}`);
    console.log(`🔗 https://solscan.io/tx/${signature}`);
    
    // Step 5: Confirm transaction
    const confirmation = await connection.confirmTransaction(
      signature,
      'confirmed'
    );
    
    if (confirmation.value.err) {
      console.error('❌ Transaction failed:', confirmation.value.err);
      return null;
    }
    
    console.log('✅ BUY SUCCESSFUL!');
    return signature;
    
  } catch (error) {
    console.error('❌ Buy execution error:', error.message);
    
    if (error.response) {
      console.error('API Error:', error.response.data);
    }
    
    return null;
  }
}
```

### Alternative: Raydium Direct Swap

```typescript
import { Liquidity, Token, TokenAmount, Percent } from '@raydium-io/raydium-sdk';

async function buyOnRaydium(
  tokenMint: string,
  solAmount: number
): Promise<string | null> {
  
  try {
    // Fetch pool keys for this token
    const poolKeys = await fetchRaydiumPoolKeys(tokenMint);
    
    if (!poolKeys) {
      console.log('❌ No Raydium pool found');
      return null;
    }
    
    const inputToken = new Token(
      Token.WSOL.mint,
      Token.WSOL.decimals,
      Token.WSOL.symbol
    );
    
    const outputToken = new Token(
      new PublicKey(tokenMint),
      6, // Adjust based on token decimals
      'TOKEN'
    );
    
    const inputAmount = new TokenAmount(
      inputToken,
      Math.floor(solAmount * 1e9)
    );
    
    const slippage = new Percent(
      parseInt(process.env.MAX_SLIPPAGE || '8'),
      100
    );
    
    // Build swap transaction
    const { transaction, signers } = await Liquidity.makeSwapTransaction({
      connection,
      poolKeys,
      userKeys: {
        tokenAccountIn: solTokenAccount,
        tokenAccountOut: targetTokenAccount,
        owner: wallet.publicKey
      },
      amountIn: inputAmount,
      amountOut: new TokenAmount(outputToken, 0),
      fixedSide: 'in',
      config: {
        bypassAssociatedCheck: false
      }
    });
    
    // Add priority fee
    transaction.add(
      ComputeBudgetProgram.setComputeUnitPrice({
        microLamports: parseInt(process.env.PRIORITY_FEE_MICROLAMPORTS || '100000')
      })
    );
    
    // Send transaction
    const signature = await sendAndConfirmTransaction(
      connection,
      transaction,
      [wallet, ...signers],
      {
        skipPreflight: true,
        commitment: 'confirmed'
      }
    );
    
    console.log('✅ Raydium buy successful:', signature);
    return signature;
    
  } catch (error) {
    console.error('Raydium buy error:', error);
    return null;
  }
}
```

### Auto Token Account Creation

```typescript
import { getOrCreateAssociatedTokenAccount } from '@solana/spl-token';

async function ensureTokenAccount(tokenMint: string): Promise<PublicKey> {
  const mintPubkey = new PublicKey(tokenMint);
  
  const tokenAccount = await getOrCreateAssociatedTokenAccount(
    connection,
    wallet, // payer
    mintPubkey,
    wallet.publicKey // owner
  );
  
  console.log(`✅ Token account ready: ${tokenAccount.address.toBase58()}`);
  return tokenAccount.address;
}
```

### Debugging Checkpoint 5
- ✅ Jupiter API responding?
- ✅ Transactions being signed correctly?
- ✅ Priority fees being applied?
- ✅ Getting transaction confirmations?
- ✅ Handling slippage errors?

---

## Phase 7: Complete Bot Logic Flow

### Main Execution Function

```typescript
import { PublicKey } from '@solana/web3.js';

// Track processed transactions to avoid duplicates
const processedSignatures = new Set<string>();

async function processTokenBuy(lockData: StreamflowLockData): Promise<void> {
  const startTime = Date.now();
  
  // Duplicate check
  if (processedSignatures.has(lockData.signature)) {
    console.log('⏭️ Already processed, skipping');
    return;
  }
  processedSignatures.add(lockData.signature);
  
  console.log('\n' + '='.repeat(60));
  console.log('🎯 NEW STREAMFLOW LOCK DETECTED');
  console.log('=' .repeat(60));
  console.log('Token:', lockData.tokenMint);
  console.log('Amount:', lockData.lockedAmount);
  console.log('Signature:', lockData.signature);
  console.log('Time:', new Date(lockData.timestamp * 1000).toISOString());
  console.log('='.repeat(60) + '\n');
  
  try {
    // Step 1: Market Cap Validation
    console.log('Step 1: Validating market cap...');
    const marketCapValid = await validateMarketCap(lockData.tokenMint);
    
    if (!marketCapValid) {
      console.log('❌ Market cap validation failed - SKIPPING\n');
      return;
    }
    
    // Step 2: Safety Checks
    console.log('\nStep 2: Running safety checks...');
    const safetyPassed = await performSafetyChecks(lockData.tokenMint);
    
    if (!safetyPassed) {
      console.log('❌ Safety checks failed - SKIPPING\n');
      return;
    }
    
    // Step 3: Top Holder Check (optional)
    console.log('\nStep 3: Checking top holders...');
    const holderCheckPassed = await checkTopHolders(lockData.tokenMint);
    
    if (!holderCheckPassed) {
      console.log('❌ Top holder check failed - SKIPPING\n');
      return;
    }
    
    // Step 4: Ensure token account exists
    console.log('\nStep 4: Preparing token account...');
    await ensureTokenAccount(lockData.tokenMint);
    
    // Step 5: Execute buy
    console.log('\nStep 5: EXECUTING BUY...');
    
    const buyAmount = parseFloat(process.env.BUY_AMOUNT_SOL || '0.1');
    
    // Dry run check
    if (process.env.DRY_RUN === 'true') {
      console.log('🧪 DRY RUN MODE - Would buy:');
      console.log(`   Amount: ${buyAmount} SOL`);
      console.log(`   Token: ${lockData.tokenMint}`);
      console.log('   (No actual transaction sent)\n');
      return;
    }
    
    const signature = await executeBuy(lockData.tokenMint, buyAmount);
    
    if (signature) {
      const elapsed = Date.now() - startTime;
      console.log('\n' + '✅'.repeat(30));
      console.log(`🎉 BUY EXECUTED SUCCESSFULLY IN ${elapsed}ms`);
      console.log(`📊 Token: ${lockData.tokenMint}`);
      console.log(`💰 Amount: ${buyAmount} SOL`);
      console.log(`📝 TX: https://solscan.io/tx/${signature}`);
      console.log('✅'.repeat(30) + '\n');
      
      // Optional: Add to database/log file
      await logSuccessfulTrade({
        token: lockData.tokenMint,
        amount: buyAmount,
        signature,
        lockSignature: lockData.signature,
        elapsed
      });
      
      // Cooldown between buys
      const cooldown = parseInt(process.env.COOLDOWN_BETWEEN_BUYS_MS || '3000');
      console.log(`⏸️ Cooling down for ${cooldown}ms...\n`);
      await sleep(cooldown);
      
    } else {
      console.log('❌ Buy execution failed\n');
    }
    
  } catch (error) {
    console.error('❌ Error processing token buy:', error);
    console.error(error.stack);
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function logSuccessfulTrade(data: any): Promise<void> {
  const logEntry = {
    timestamp: new Date().toISOString(),
    ...data
  };
  
  // Log to file
  const fs = require('fs');
  fs.appendFileSync(
    'successful-trades.jsonl',
    JSON.stringify(logEntry) + '\n'
  );
  
  // Optional: Send to Discord/Telegram
  // await sendNotification(logEntry);
}
```

### Entry Point

```typescript
async function main() {
  console.log('🚀 Streamflow Wallet Monitor & Auto-Sniper Bot');
  console.log('=' .repeat(60));
  console.log('Target Wallet:', TARGET_WALLET.toBase58());
  console.log('Streamflow Program:', STREAMFLOW_PROGRAM.toBase58());
  console.log('Market Cap Range: $' + 
    `${process.env.MIN_MARKET_CAP} - $${process.env.MAX_MARKET_CAP}`);
  console.log('Buy Amount:', process.env.BUY_AMOUNT_SOL, 'SOL');
  console.log('Max Slippage:', process.env.MAX_SLIPPAGE + '%');
  console.log('Dry Run:', process.env.DRY_RUN || 'false');
  console.log('=' .repeat(60) + '\n');
  
  // Start monitoring
  console.log('👀 Starting wallet monitor...\n');
  
  // WebSocket subscription
  const subscriptionId = connection.onLogs(
    TARGET_WALLET,
    async (logs, context) => {
      const isStreamflowTx = logs.logs.some(log => 
        log.includes(STREAMFLOW_PROGRAM.toBase58())
      );
      
      if (isStreamflowTx) {
        await handleStreamflowLock(logs.signature);
      }
    },
    'confirmed'
  );
  
  console.log(`📡 Monitoring active (Subscription: ${subscriptionId})`);
  console.log('Press Ctrl+C to stop\n');
  
  // Keep process alive
  process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down...');
    connection.removeOnLogsListener(subscriptionId);
    process.exit(0);
  });
}

// Start the bot
main().catch(console.error);
```

---

## Phase 8: Error Handling & Edge Cases

### Comprehensive Error Handling

```typescript
class BotError extends Error {
  constructor(
    message: string,
    public code: string,
    public recoverable: boolean = true
  ) {
    super(message);
    this.name = 'BotError';
  }
}

async function handleStreamflowLock(signature: string): Promise<void> {
  try {
    const lockData = await parseStreamflowTransaction(signature);
    
    if (!lockData) {
      throw new BotError(
        'Failed to parse transaction',
        'PARSE_ERROR',
        false
      );
    }
    
    await processTokenBuy(lockData);
    
  } catch (error) {
    if (error instanceof BotError) {
      console.error(`[${error.code}] ${error.message}`);
      
      if (!error.recoverable) {
        console.error('Non-recoverable error - skipping');
        return;
      }
    }
    
    // Retry logic for recoverable errors
    if (error.message.includes('429') || error.message.includes('timeout')) {
      console.log('Rate limited or timeout - retrying in 2s...');
      await sleep(2000);
      // Optionally retry
    }
    
    console.error('Error details:', error);
  }
}
```

### Transaction Failure Handling

```typescript
async function executeBuyWithRetry(
  tokenMint: string,
  solAmount: number,
  maxRetries: number = 3
): Promise<string | null> {
  
  let slippage = parseInt(process.env.MAX_SLIPPAGE || '8');
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`Attempt ${attempt}/${maxRetries} (slippage: ${slippage}%)`);
      
      const signature = await executeBuy(tokenMint, solAmount);
      
      if (signature) {
        return signature;
      }
      
    } catch (error) {
      console.error(`Attempt ${attempt} failed:`, error.message);
      
      // Handle slippage errors by increasing tolerance
      if (error.message.includes('slippage') && attempt < maxRetries) {
        slippage += 2;
        console.log(`Increasing slippage to ${slippage}% and retrying...`);
        await sleep(500);
        continue;
      }
      
      // Handle insufficient liquidity
      if (error.message.includes('insufficient')) {
        console.error('Insufficient liquidity - cannot buy');
        return null;
      }
      
      if (attempt === maxRetries) {
        console.error('Max retries reached - giving up');
        return null;
      }
      
      await sleep(1000 * attempt);
    }
  }
  
  return null;
}
```

### Connection Management

```typescript
class RobustConnection {
  private connections: Connection[];
  private currentIndex: number = 0;
  
  constructor(endpoints: string[]) {
    this.connections = endpoints.map(
      endpoint => new Connection(endpoint, 'confirmed')
    );
  }
  
  getConnection(): Connection {
    return this.connections[this.currentIndex];
  }
  
  rotateConnection(): void {
    this.currentIndex = (this.currentIndex + 1) % this.connections.length;
    console.log(`🔄 Rotated to RPC endpoint ${this.currentIndex + 1}`);
  }
  
  async executeWithFallback<T>(
    operation: (conn: Connection) => Promise<T>
  ): Promise<T> {
    for (let i = 0; i < this.connections.length; i++) {
      try {
        const result = await operation(this.getConnection());
        return result;
      } catch (error) {
        console.error(`RPC ${i + 1} failed:`, error.message);
        this.rotateConnection();
        
        if (i === this.connections.length - 1) {
          throw error;
        }
      }
    }
    
    throw new Error('All RPC endpoints failed');
  }
}

// Usage
const robustConn = new RobustConnection([
  process.env.RPC_ENDPOINT_1,
  process.env.RPC_ENDPOINT_2,
  process.env.RPC_ENDPOINT_3
]);

const tx = await robustConn.executeWithFallback(
  conn => conn.getParsedTransaction(signature)
);
```

---

## Phase 9: Testing & Deployment

### Testing Checklist

```typescript
// Test configuration
const TEST_CONFIG = {
  // Use a test transaction signature from the target wallet
  testSignature: 'YOUR_TEST_SIGNATURE_HERE',
  
  // Use a known token for testing
  testTokenMint: 'KNOWN_TOKEN_MINT_HERE',
  
  // Small test amount
  testBuyAmount: 0.01,
  
  // Enable dry run
  dryRun: true
};

async function runTests() {
  console.log('🧪 Running bot tests...\n');
  
  // Test 1: Connection
  console.log('Test 1: RPC Connection');
  try {
    const slot = await connection.getSlot();
    console.log('✅ Connected - Current slot:', slot);
  } catch (error) {
    console.log('❌ Connection failed:', error.message);
    return;
  }
  
  // Test 2: Parse known transaction
  console.log('\nTest 2: Parse Streamflow Transaction');
  try {
    const lockData = await parseStreamflowTransaction(TEST_CONFIG.testSignature);
    console.log('✅ Parsed:', lockData);
  } catch (error) {
    console.log('❌ Parsing failed:', error.message);
  }
  
  // Test 3: Market cap fetch
  console.log('\nTest 3: Fetch Market Data');
  try {
    const marketData = await getMarketCapData(TEST_CONFIG.testTokenMint);
    console.log('✅ Market data:', marketData);
  } catch (error) {
    console.log('❌ Market data failed:', error.message);
  }
  
  // Test 4: Safety checks
  console.log('\nTest 4: Safety Checks');
  try {
    const safe = await performSafetyChecks(TEST_CONFIG.testTokenMint);
    console.log('✅ Safety result:', safe);
  } catch (error) {
    console.log('❌ Safety checks failed:', error.message);
  }
  
  // Test 5: Jupiter quote
  console.log('\nTest 5: Get Jupiter Quote');
  try {
    const response = await axios.get(
      'https://quote-api.jup.ag/v6/quote',
      {
        params: {
          inputMint: SOL_MINT,
          outputMint: TEST_CONFIG.testTokenMint,
          amount: TEST_CONFIG.testBuyAmount * 1e9,
          slippageBps: 50
        }
      }
    );
    console.log('✅ Quote received:', response.data.outAmount);
  } catch (error) {
    console.log('❌ Quote failed:', error.message);
  }
  
  console.log('\n✅ All tests completed!');
}

// Run tests before starting bot
if (process.argv.includes('--test')) {
  runTests().then(() => process.exit(0));
}
```

### Deployment Options

**Option 1: Local Machine (Development)**
```bash
# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
nano .env

# Run in dry-run mode first
DRY_RUN=true npm start

# Once confident, run live
npm start
```

**Option 2: VPS (Production)**
```bash
# Use PM2 for process management
npm install -g pm2

# Start bot with PM2
pm start dist/bot.js --name streamflow-sniper

# View logs
pm2 logs streamflow-sniper

# Monitor
pm2 monit

# Auto-restart on server reboot
pm2 startup
pm2 save
```

**Option 3: Docker**
```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

CMD ["node", "dist/bot.js"]
```

```bash
# Build and run
docker build -t streamflow-sniper .
docker run -d --name sniper --env-file .env streamflow-sniper

# View logs
docker logs -f sniper
```

### Monitoring & Alerts

```typescript
// Discord webhook for notifications
async function sendDiscordAlert(message: string, color: number = 0x00ff00) {
  if (!process.env.DISCORD_WEBHOOK) return;
  
  try {
    await axios.post(process.env.DISCORD_WEBHOOK, {
      embeds: [{
        title: '🎯 Streamflow Sniper Alert',
        description: message,
        color: color,
        timestamp: new Date().toISOString()
      }]
    });
  } catch (error) {
    console.error('Discord alert failed:', error.message);
  }
}

// Usage
await sendDiscordAlert(
  `✅ Bought token: ${tokenMint}\nAmount: ${amount} SOL\nTX: ${signature}`,
  0x00ff00 // Green
);

await sendDiscordAlert(
  `❌ Buy failed: ${error.message}`,
  0xff0000 // Red
);
```

---

## Phase 10: Optimization & Advanced Features

### Speed Optimizations

1. **Pre-warm Connections**
```typescript
// Keep connections warm
setInterval(async () => {
  try {
    await connection.getSlot();
  } catch (error) {
    console.error('Connection health check failed');
  }
}, 30000); // Every 30 seconds
```

2. **Parallel Processing**
```typescript
async function processTokenBuyParallel(lockData: StreamflowLockData) {
  // Run independent checks in parallel
  const [marketCapValid, safetyPassed, holderCheckPassed] = await Promise.all([
    validateMarketCap(lockData.tokenMint),
    performSafetyChecks(lockData.tokenMint),
    checkTopHolders(lockData.tokenMint)
  ]);
  
  if (!marketCapValid || !safetyPassed || !holderCheckPassed) {
    console.log('❌ Validation failed - SKIPPING');
    return;
  }
  
  // Proceed to buy
  await executeBuy(lockData.tokenMint, buyAmount);
}
```

3. **Token Account Pre-creation**
```typescript
// Pre-create accounts for popular tokens
const popularTokens = [
  'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', // USDC
  // Add more
];

async function preCreateTokenAccounts() {
  for (const mint of popularTokens) {
    try {
      await ensureTokenAccount(mint);
      console.log(`✅ Pre-created account for ${mint}`);
    } catch (error) {
      console.error(`Failed to pre-create ${mint}:`, error.message);
    }
  }
}
```

---

## Quick Start Guide

### Step 1: Clone and Setup
```bash
# Create project directory
mkdir streamflow-sniper
cd streamflow-sniper

# Initialize project
npm init -y
npm install @solana/web3.js @solana/spl-token bs58 dotenv axios

# Create TypeScript config
npx tsc --init
```

### Step 2: Create .env File
```env
RPC_ENDPOINT=https://your-rpc-here.com
RPC_WEBSOCKET=wss://your-rpc-here.com
PRIVATE_KEY=your_private_key_base58

TARGET_WALLET=B743wFVk2pCYhV91cn287e1xY7f1vt4gdY48hhNiuQmT
STREAMFLOW_PROGRAM_ID=strmRqUCoQUgGUan5YhzUZa6KqdzwX5L6FpUxfmKg5m

MIN_MARKET_CAP=10000
MAX_MARKET_CAP=500000

BUY_AMOUNT_SOL=0.1
MAX_SLIPPAGE=8
MIN_LIQUIDITY_SOL=2
PRIORITY_FEE_MICROLAMPORTS=100000

DRY_RUN=true
ENABLE_DUPLICATE_CHECK=true
COOLDOWN_BETWEEN_BUYS_MS=3000

DISCORD_WEBHOOK=your_discord_webhook_url
```

### Step 3: Copy Bot Code
- Copy all the TypeScript code from this document into `src/bot.ts`
- Organize into modules as needed

### Step 4: Test in Dry Run Mode
```bash
# Compile TypeScript
npx tsc

# Run in dry-run mode
DRY_RUN=true node dist/bot.js

# If working correctly, you should see:
# 👀 Monitoring wallet: B743wFVk2pCYhV91cn287e1xY7f1vt4gdY48hhNiuQmT
# 📡 Monitoring active
```

### Step 5: Go Live (When Ready)
```bash
# Disable dry run in .env
DRY_RUN=false

# Run bot
node dist/bot.js

# Or with PM2 for production
pm2 start dist/bot.js --name streamflow-sniper
```

---

## Debugging Quick Reference

### Issue: No transactions detected
**Check:**
- ✅ Target wallet address correct?
- ✅ WebSocket connection active?
- ✅ RPC endpoint working?
- ✅ Wallet has recent Streamflow activity?

**Test:**
```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getSignaturesForAddress","params":["B743wFVk2pCYhV91cn287e1xY7f1vt4gdY48hhNiuQmT",{"limit":10}]}' \
  YOUR_RPC_ENDPOINT
```

### Issue: Market cap validation always fails
**Check:**
- ✅ DexScreener API responding?
- ✅ Market cap thresholds appropriate?
- ✅ Token actually listed on DEX?

**Test:**
```bash
curl https://api.dexscreener.com/latest/dex/tokens/SOME_TOKEN_MINT
```

### Issue: Transactions failing
**Check:**
- ✅ Sufficient SOL in wallet?
- ✅ Priority fees high enough?
- ✅ Slippage tolerance adequate?
- ✅ Token account created?

**View logs:**
```bash
pm2 logs streamflow-sniper --lines 100
```

---

## Security Reminders

⚠️ **CRITICAL:**
- Never share your private key
- Start with small amounts (0.01-0.1 SOL)
- Test in dry-run mode extensively
- Use a dedicated wallet for the bot
- Monitor bot activity regularly
- Set up alerts for failures
- Keep only necessary SOL in hot wallet
- Back up your configuration

---

## Final Notes

This workflow provides a complete **wallet-targeted Streamflow lock sniper** that:
- ✅ Monitors specific wallet address
- ✅ Detects Streamflow locks instantly
- ✅ Validates market cap range
- ✅ Performs safety checks
- ✅ Executes instant buys via Jupiter
- ✅ Handles errors gracefully
- ✅ Provides comprehensive logging

**Key Success Factors:**
1. Fast RPC endpoint (Helius/QuickNode)
2. Proper market cap validation
3. High priority fees for speed
4. Thorough testing before going live
5. Monitoring and alerts
6. Risk management (stop loss, position sizing)

**Start conservatively, test thoroughly, and scale gradually!**

Good luck with your Streamflow sniper bot! 🚀