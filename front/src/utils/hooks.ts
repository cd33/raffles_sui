// import {
//   SuiClient,
//   SuiObjectData,
//   getFullnodeUrl,
// } from "@mysten/sui.js/client";
// import { useEffect, useState } from "react";

// const NETWORK = import.meta.env.VITE_NETWORK;
// const rpcUrl = getFullnodeUrl(NETWORK);
// const client = new SuiClient({ url: rpcUrl });

// export const useQuadrantResponses = (addresses: string[], interval: number) => {
//   const [responses, setResponses] = useState<(SuiObjectData | null)[]>([]);

//   useEffect(() => {
//     const fetchData = async () => {
//       if (client) {
//         const newResponses = await Promise.all(
//           addresses.map(async (address) => {
//             const res = await client.getObject({
//               id: address,
//               options: {
//                 showContent: true,
//               },
//             });
//             return res?.data || null;
//           })
//         );
//         setResponses(newResponses);
//       }
//     };

//     fetchData();
//     const intervalId = setInterval(fetchData, interval * 1000);
//     return () => clearInterval(intervalId);
//   }, [addresses, interval]);

//   return responses;
// };
