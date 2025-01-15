import { Asset, canonizeId, Fee, Token } from '@chimera-monorepo/utils';
import { keccak256, defaultAbiCoder, isHexString } from 'ethers/lib/utils';
import { getContext } from '../context';
import { getContract } from '../mockable';

export const getAssetHash = (address: string, domain: string): string => {
  // Return the asset hash.
  return keccak256(
    defaultAbiCoder.encode(['bytes32', 'uint32'], [isHexString(address, 32) ? address : canonizeId(address), domain]),
  );
};

export const getRegisteredAssetHashFromContract = async (tickerHash: string, domain: string): Promise<string> => {
  const {
    config,
    adapters: { chainreader },
  } = getContext();

  // Get the asset config.
  const hubEverclear = getContract(config.hub.deployments.everclear, config.abis.hub.everclear);
  const encodedAssetHash = await chainreader.readTx(
    {
      to: hubEverclear.address,
      domain: +config.hub.domain,
      data: hubEverclear.interface.encodeFunctionData('assetHash', [tickerHash, domain]),
    },
    'latest',
  );
  const [assetHash] = hubEverclear.interface.decodeFunctionResult('assetHash', encodedAssetHash);

  return assetHash;
};

export const getAssetFromContract = async (address: string, domain: string): Promise<Asset> => {
  const {
    config,
    adapters: { chainreader },
  } = getContext();

  // Get the asset hash.
  const assetHash = getAssetHash(address, domain);

  // Get the asset config.
  const hubEverclear = getContract(config.hub.deployments.everclear, config.abis.hub.everclear);
  const encodedAssetConfig = await chainreader.readTx(
    {
      to: hubEverclear.address,
      domain: +config.hub.domain,
      data: hubEverclear.interface.encodeFunctionData('adoptedForAssets', [assetHash]),
    },
    'latest',
  );
  const [assetConfig] = hubEverclear.interface.decodeFunctionResult('adoptedForAssets', encodedAssetConfig);

  return { ...assetConfig, id: assetConfig.tickerHash };
};

export const getTokenFromContract = async (tickerHash: string): Promise<Token> => {
  const {
    config,
    adapters: { chainreader },
  } = getContext();

  // Get the token config.
  const hubEverclear = getContract(config.hub.deployments.everclear, config.abis.hub.everclear);
  const encodedTokenConfig = await chainreader.readTx(
    {
      to: hubEverclear.address,
      domain: +config.hub.domain,
      data: hubEverclear.interface.encodeFunctionData('tokenConfigs', [tickerHash]),
    },
    'latest',
  );
  const tokenConfig = hubEverclear.interface.decodeFunctionResult('tokenConfigs', encodedTokenConfig);
  // Get the protocol fees
  const encodedFees = await chainreader.readTx(
    {
      to: hubEverclear.address,
      domain: +config.hub.domain,
      data: hubEverclear.interface.encodeFunctionData('tokenFees', [tickerHash]),
    },
    'latest',
  );
  const [decodedFees] = hubEverclear.interface.decodeFunctionResult('tokenFees', encodedFees);

  return {
    id: tickerHash,
    maxDiscountBps: tokenConfig._maxDiscountDbps,
    discountPerEpoch: tokenConfig._discountPerEpoch,
    prioritizedStrategy: tokenConfig._prioritizedStrategy,
    feeAmounts: decodedFees.map((f: Fee) => f.fee),
    feeRecipients: decodedFees.map((f: Fee) => f.recipient),
  };
};

export const getCustodiedAssetsFromHubContract = async (assetHash: string): Promise<string> => {
  const {
    config,
    adapters: { chainreader },
  } = getContext();

  // Get the asset config.
  const hubEverclear = getContract(config.hub.deployments.everclear, config.abis.hub.everclear);
  const encoded = await chainreader.readTx(
    {
      to: hubEverclear.address,
      domain: +config.hub.domain,
      data: hubEverclear.interface.encodeFunctionData('custodiedAssets', [assetHash]),
    },
    'latest',
  );
  const [custodied] = hubEverclear.interface.decodeFunctionResult('custodiedAssets', encoded);

  return custodied;
};
