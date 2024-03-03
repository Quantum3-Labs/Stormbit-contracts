const creditScoreArray = args[0];
const borrowerAddress = args[1];

const request = Functions.makeHttpRequest({
  url: `https://api.stormbit/api/creditScores/${creditScoreArray}/${borrowerAddress}`,
  method: "GET",
});

const [response] = await Promise.all([request]);

return Functions.encodeUint256(response);