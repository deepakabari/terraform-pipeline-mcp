const itemService = require('../services/itemService');

const getAllItems = (req, res) => {
    const items = itemService.getAllItems();
    res.status(200).json({ data: items });
};

const getItemById = (req, res) => {
    const item = itemService.getItemById(req.params.id);
    if (!item) {
        return res.status(404).json({ error: 'Item not found' });
    }
    res.status(200).json({ data: item });
};

const createItem = (req, res) => {
    const newItem = req.body;
    if (!newItem.name) {
        return res.status(400).json({ error: 'Name is required' });
    }
    const createdItem = itemService.createItem(newItem);
    res.status(201).json({ data: createdItem });
};

const updateItem = (req, res) => {
    const updatedItem = itemService.updateItem(req.params.id, req.body);
    if (!updatedItem) {
        return res.status(404).json({ error: 'Item not found' });
    }
    res.status(200).json({ data: updatedItem });
};

const deleteItem = (req, res) => {
    const isDeleted = itemService.deleteItem(req.params.id);
    if (!isDeleted) {
        return res.status(404).json({ error: 'Item not found' });
    }
    res.status(204).send();
};

module.exports = {
    getAllItems,
    getItemById,
    createItem,
    updateItem,
    deleteItem
};
