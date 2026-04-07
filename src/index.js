const express = require('express');
const itemRoutes = require('./routes/itemRoutes');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware to parse JSON
app.use(express.json());

// Routes
app.use('/api/items', itemRoutes);

// Health check endpoint for AWS
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'OK', message: 'Application is running smoothly' });
});

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
