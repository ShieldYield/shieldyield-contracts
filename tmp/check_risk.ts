
import { createPublicClient, http, type Address } from "viem";
import { arbitrumSepolia } from "viem/chains";

const RISK_REGISTRY = "0xB66fC87e8e46acF6478f6924Ea8D87331E638BdD";
const YIELD_MAX = "0x2F3dAA21af1C1D035789BA157802C02fa54294af";

const ABI = [
    {
        name: "getProtocolRisk",
        type: "function",
        stateMutability: "view",
        inputs: [{ name: "protocol", type: "address" }],
        outputs: [
            {
                name: "",
                type: "tuple",
                components: [
                    { name: "riskScore", type: "uint8" },
                    { name: "threatLevel", type: "uint8" },
                    { name: "lastUpdated", type: "uint256" },
                    { name: "isActive", type: "bool" },
                ],
            },
        ],
    },
];

async function check() {
    const client = createPublicClient({ chain: arbitrumSepolia, transport: http() });
    const risk = await client.readContract({
        address: RISK_REGISTRY as Address,
        abi: ABI,
        functionName: "getProtocolRisk",
        args: [YIELD_MAX as Address],
    });
    console.log("Risk for YieldMax:", JSON.stringify(risk, (key, value) => typeof value === 'bigint' ? value.toString() : value, 2));
}

check();
