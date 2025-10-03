import fetch from 'node-fetch';

async function testApi() {
  const payload = {
    origin: "8453", // Example domain ID for origin
    destinations: ["10"], // Example domain ID for destination
    to: "0xade09131C6f43fe22C2CbABb759636C43cFc181e", // Example address
    inputAsset: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913", // USDC address on Base
    amount: "1000000", // Example amount
    callData: "", // Example callData
    maxFee: "500", // Example max fee in BPS
    // isFastPath: true, // Example fast path condition
    permit2Params: {
      nonce: "0", // Example nonce
      deadline: "0", // Example deadline
      signature: "0x", // Example signature
    },
  };

  try {
    const response = await fetch('https://api.staging.everclear.org/intents', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-admin-token': '3v3rcl34r43v3r', // Example admin token
      },
      body: JSON.stringify(payload),
    });

    const data = await response.json();
    console.log('API Response:', data);
  } catch (error) {
    console.error('Error:', error);
  }
}

testApi();
