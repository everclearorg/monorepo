# 🔐 Tron Key Management - Security Best Practices

## Overview

This document outlines industry best practices for managing Tron private keys securely in the Everclear system. **Never hardcode private keys in source code.**

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Application   │───▶│  TronKeyManager  │───▶│  Key Provider   │
│                 │    │                  │    │                 │
│ • Relayer       │    │ • Validation     │    │ • Environment   │
│ • Signer        │    │ • Caching        │    │ • KMS           │
│ • Provider      │    │ • Fallback       │    │ • HSM           │
└─────────────────┘    └──────────────────┘    │ • HD Wallet     │
                                                └─────────────────┘
```

## 🔑 Key Storage Methods (Priority Order)

### 1. **Environment Variables** (Development/Staging)
```bash
# Primary environment variable
export TRON_PRIVATE_KEY="your_64_character_hex_private_key"

# Alternative names (checked in order)
export TRON_SIGNER_PRIVATE_KEY="your_private_key"
export RELAYER_TRON_PRIVATE_KEY="your_private_key"
```

**Pros:**
- ✅ Simple to implement
- ✅ Not stored in code
- ✅ Easy to rotate

**Cons:**
- ❌ Visible in process environment
- ❌ Limited access control
- ❌ Not suitable for production

### 2. **AWS KMS** (Production Recommended)
```bash
export TRON_KMS_KEY_ID="arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
export AWS_REGION="us-east-1"
```

**Pros:**
- ✅ Hardware-backed security
- ✅ Centralized key management
- ✅ Audit trails
- ✅ Access control policies
- ✅ Automatic key rotation

**Cons:**
- ❌ Cloud provider dependency
- ❌ Additional complexity
- ❌ Cost considerations

### 3. **Hardware Security Modules (HSM)** (Enterprise)
```bash
export TRON_HSM_SLOT_ID="0"
export TRON_HSM_PIN="your_hsm_pin"
export TRON_HSM_LIBRARY_PATH="/usr/lib/libpkcs11.so"
```

**Pros:**
- ✅ Highest security level
- ✅ FIPS 140-2 Level 3 certified
- ✅ Tamper-resistant hardware
- ✅ On-premises control

**Cons:**
- ❌ High cost
- ❌ Complex setup
- ❌ Specialized knowledge required

### 4. **HD Wallets** (Hierarchical Deterministic)
```bash
export TRON_MNEMONIC="your twelve word mnemonic phrase here"
export TRON_HD_PATH="m/44'/195'/0'/0/0"  # Tron BIP44 path
```

**Pros:**
- ✅ Single seed for multiple keys
- ✅ Deterministic key derivation
- ✅ Easy backup and recovery
- ✅ Industry standard (BIP32/BIP44)

**Cons:**
- ❌ Seed compromise affects all keys
- ❌ Additional implementation complexity

## 🚀 Implementation

### Basic Usage
```typescript
import { TronKeyManager } from '@chimera-monorepo/utils';

const keyManager = new TronKeyManager({
  environment: 'production',
  fallbackToTestKey: false, // Never true in production
});

// Get private key securely
const privateKey = await keyManager.getPrivateKey();

// Get TronWeb instance
const tronWeb = await keyManager.createTronWeb();

// Get address without exposing private key
const address = await keyManager.getAddress();
```

### Advanced Configuration
```typescript
const keyManager = new TronKeyManager({
  environment: process.env.NODE_ENV as 'development' | 'staging' | 'production',
  fallbackToTestKey: process.env.NODE_ENV === 'development',
  logger: customLogger,
});
```

## 🔧 Environment Configuration

Create a `.env` file (never commit to git):

```bash
# =============================================================================
# TRON BLOCKCHAIN CONFIGURATION
# =============================================================================

# Environment
NODE_ENV=production

# Method 1: Direct Private Key (Dev/Staging only)
TRON_PRIVATE_KEY=your_64_character_hex_private_key_here

# Method 2: AWS KMS (Production)
TRON_KMS_KEY_ID=arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012
AWS_REGION=us-east-1

# Method 3: HD Wallet
TRON_MNEMONIC="your twelve word mnemonic phrase here"
TRON_HD_PATH="m/44'/195'/0'/0/0"

# Network Configuration
TRON_RPC_URL=https://api.trongrid.io
TRON_NETWORK=mainnet

# Security
TRON_RATE_LIMIT_ENABLED=true
TRON_RATE_LIMIT_PER_MINUTE=10
```

## 🛡️ Security Best Practices

### 1. **Key Generation**
```bash
# Generate secure private key
openssl rand -hex 32

# Generate mnemonic
npm install -g bip39-cli
bip39-cli generate --words 12

# Verify Tron address
node -e "
const TronWeb = require('tronweb');
const t = new TronWeb({
  fullHost: 'https://api.trongrid.io',
  privateKey: 'YOUR_PRIVATE_KEY'
});
console.log('Address:', t.defaultAddress.base58);
"
```

### 2. **Key Rotation**
```typescript
// Rotate keys regularly
const keyManager = new TronKeyManager(options);

// Clear cached keys
keyManager.clearCache();

// Update environment variable
process.env.TRON_PRIVATE_KEY = newPrivateKey;
```

### 3. **Access Control**
- Use IAM roles for KMS access
- Implement IP whitelisting
- Enable audit logging
- Monitor key usage patterns

### 4. **Backup and Recovery**
- Store encrypted backups offline
- Document recovery procedures
- Test disaster recovery regularly
- Use multi-signature wallets for critical operations

## 🏢 Production Deployment

### Pre-deployment Checklist
- [ ] Remove all test private keys
- [ ] Configure KMS/HSM
- [ ] Set up key rotation
- [ ] Enable monitoring and alerting
- [ ] Configure IP whitelisting
- [ ] Test backup and recovery
- [ ] Document procedures
- [ ] Train operations team

### Monitoring
```typescript
// Monitor key usage
keyManager.on('keyUsed', (event) => {
  logger.info('Key used for transaction', {
    address: event.address,
    timestamp: event.timestamp,
    transactionType: event.type,
  });
});

// Alert on suspicious activity
keyManager.on('suspiciousActivity', (event) => {
  alerting.sendAlert('Suspicious Tron key activity detected', event);
});
```

## 🔍 Troubleshooting

### Common Issues

1. **"No Tron private key available"**
   - Check environment variables are set
   - Verify key format (64 hex characters)
   - Ensure KMS permissions are correct

2. **"Invalid private key format"**
   - Private key must be 64 hexadecimal characters
   - Remove any '0x' prefix
   - Check for whitespace or special characters

3. **"KMS access denied"**
   - Verify IAM permissions
   - Check AWS credentials
   - Ensure KMS key exists and is enabled

### Debug Mode
```bash
export TRON_DEBUG=true
export TRON_LOG_LEVEL=debug
```

## 📚 Industry Standards

### Compliance
- **SOC 2 Type II**: Implement proper key management controls
- **PCI DSS**: Follow cryptographic key management requirements
- **ISO 27001**: Implement information security management
- **NIST Cybersecurity Framework**: Follow key management guidelines

### Tron-Specific Standards
- **TIP-191**: Tron signature standard
- **BIP44**: HD wallet derivation path `m/44'/195'/0'/0/0`
- **TronGrid API**: Official Tron network API

## 🎯 Recommendations by Environment

### Development
```typescript
const keyManager = new TronKeyManager({
  environment: 'development',
  fallbackToTestKey: true, // OK for development
});
```

### Staging
```typescript
const keyManager = new TronKeyManager({
  environment: 'staging',
  fallbackToTestKey: false, // Use real keys
});
```

### Production
```typescript
const keyManager = new TronKeyManager({
  environment: 'production',
  fallbackToTestKey: false, // Never use test keys
});
```

## 🔗 Related Documentation

- [Tron Developer Documentation](https://developers.tron.network/)
- [TronWeb API Reference](https://tronweb.network/)
- [AWS KMS Developer Guide](https://docs.aws.amazon.com/kms/)
- [NIST Key Management Guidelines](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final)

---

**⚠️ SECURITY WARNING:** Never commit private keys to version control. Always use secure key management practices appropriate for your environment. 