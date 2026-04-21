const itemService = require('../services/itemService');

const getAllItems = async (req, res) => {
    try {
        const items = await itemService.getAllItems();
        res.status(200).json({ data: items });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

const getItemById = async (req, res) => {
    try {
        const item = await itemService.getItemById(req.params.id);
        if (!item) {
            return res.status(404).json({ error: 'Item not found' });
        }
        res.status(200).json({ data: item });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

const createItem = async (req, res) => {
    try {
        const newItem = req.body;
        if (!newItem.name) {
            return res.status(400).json({ error: 'Name is required' });
        }
        const createdItem = await itemService.createItem(newItem);
        res.status(201).json({ data: createdItem });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

const updateItem = async (req, res) => {
    try {
        const updatedItem = await itemService.updateItem(req.params.id, req.body);
        if (!updatedItem) {
            return res.status(404).json({ error: 'Item not found' });
        }
        res.status(200).json({ data: updatedItem });
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

const deleteItem = async (req, res) => {
    try {
        const isDeleted = await itemService.deleteItem(req.params.id);
        if (!isDeleted) {
            return res.status(404).json({ error: 'Item not found' });
        }
        res.status(204).send();
    } catch (error) {
        console.error(error);
        res.status(500).json({ error: 'Internal Server Error' });
    }
};

module.exports = {
    getAllItems,
    getItemById,
    createItem,
    updateItem,
    deleteItem
};
