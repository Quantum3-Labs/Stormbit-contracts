import express from 'express';
import axios from 'axios';
import dotenv from 'dotenv';
dotenv.config();
const app = express();
const port = 54600;
app.get('/fetchCreditScore/:address', async (req, res) => {
    const address = req.params.address;
    const accessToken = process.env.CRED_ACCESS_TOKEN;
    const url = `https://beta.credprotocol.com/api/score/address/${address}/`;
    console.log(`Access Token: ${accessToken}`);
    try {
        const response = await axios.get(url, {
            headers: {
                'Authorization': `Token ${accessToken}`
            }
        });
        console.log(`Authorization Header: Token ${accessToken}`);
        res.json(response.data);
    }
    catch (error) {
        console.error('Error fetching credit score:', error);
        if (axios.isAxiosError(error) && error.response) {
            res.status(error.response.status).send(error.response.data);
        }
        else {
            res.status(500).send('Failed to fetch credit score');
        }
    }
});
app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});
