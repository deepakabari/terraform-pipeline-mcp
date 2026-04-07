const express = require('express');
const router = express.Router();
const itemController = require('../controllers/itemController');

// GET all items
router.get('/', itemController.getAllItems);

// GET item by ID
router.get('/:id', itemController.getItemById);

// POST new item
router.post('/', itemController.createItem);

// PUT (update) item
router.put('/:id', itemController.updateItem);

// DELETE item
router.delete('/:id', itemController.deleteItem);

module.exports = router;
