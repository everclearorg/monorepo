import { Asset, canonizeId, Fee, Token, chainWrapper } from '@chimera-monorepo/utils';
import { getContext } from '../context';
import { getContract } from '../mockable';

export const getAssetHash = (address: string, domain: string): string => {
  // Return the asset hash.
  return chainWrapper.keccak256(
    chainWrapper.encodeAbiParameters(
      [{ type: 'bytes32' }, { type: 'uint32' }],
      [address.startsWith('0x') && address.length === 66 ? address : canonizeId(address), domain],
    ),
  ) as string;
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
      data: chainWrapper.encodeFunctionData({
        abi: hubEverclear.abi,
        functionName: 'assetHash',
        args: [tickerHash, domain],
      }),
      funcSig: 'assetHash(bytes32,uint32)',
    },
    'latest',
  );

  return chainWrapper.decodeFunctionResult({
    abi: hubEverclear.abi,
    functionName: 'assetHash',
    data: encodedAssetHash as `0x${string}`,
  }) as string;
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
      data: chainWrapper.encodeFunctionData({
        abi: hubEverclear.abi,
        functionName: 'adoptedForAssets',
        args: [assetHash],
      }),
      funcSig: 'adoptedForAssets(bytes32)',
    },
    'latest',
  );
  const [assetConfig] = chainWrapper.decodeFunctionResult({
    abi: hubEverclear.abi,
    functionName: 'adoptedForAssets',
    data: encodedAssetConfig as `0x${string}`,
  }) as [any];

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
      data: chainWrapper.encodeFunctionData({
        abi: hubEverclear.abi,
        functionName: 'tokenConfigs',
        args: [tickerHash],
      }),
      funcSig: 'tokenConfigs(bytes32)',
    },
    'latest',
  );
  const tokenConfig = chainWrapper.decodeFunctionResult({
    abi: hubEverclear.abi,
    functionName: 'tokenConfigs',
    data: encodedTokenConfig as `0x${string}`,
  }) as any;
  // Get the protocol fees
  const encodedFees = await chainreader.readTx(
    {
      to: hubEverclear.address,
      domain: +config.hub.domain,
      data: chainWrapper.encodeFunctionData({
        abi: hubEverclear.abi,
        functionName: 'tokenFees',
        args: [tickerHash],
      }),
      funcSig: 'tokenFees(bytes32)',
    },
    'latest',
  );
  const [decodedFees] = chainWrapper.decodeFunctionResult({
    abi: hubEverclear.abi,
    functionName: 'tokenFees',
    data: encodedFees as `0x${string}`,
  }) as [Fee[]];

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
      data: chainWrapper.encodeFunctionData({
        abi: hubEverclear.abi,
        functionName: 'custodiedAssets',
        args: [assetHash],
      }),
      funcSig: 'custodiedAssets(bytes32)',
    },
    'latest',
  );
  const custodied = chainWrapper.decodeFunctionResult({
    abi: hubEverclear.abi,
    functionName: 'custodiedAssets',
    data: encoded as `0x${string}`,
  }) as bigint;

  return custodied.toString();
};
