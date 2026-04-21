const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, ScanCommand, GetCommand, PutCommand, DeleteCommand } = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(client);

const TABLE_NAME = process.env.DYNAMODB_TABLE || 'node-express-crud-items';

const getAllItems = async () => {
    const command = new ScanCommand({ TableName: TABLE_NAME });
    const response = await docClient.send(command);
    return response.Items || [];
};

const getItemById = async (id) => {
    const command = new GetCommand({ TableName: TABLE_NAME, Key: { id } });
    const response = await docClient.send(command);
    return response.Item || null;
};

const createItem = async (itemData) => {
    // Generate an incremental ID by grabbing all existing items and finding the highest ID
    const allItems = await getAllItems();
    
    let nextId = 1;
    if (allItems.length > 0) {
        // Convert string IDs back to numbers to find the maximum value
        const maxId = Math.max(...allItems.map(item => parseInt(item.id, 10)));
        nextId = maxId + 1;
    }

    const newItem = { id: String(nextId), ...itemData };
    const command = new PutCommand({ TableName: TABLE_NAME, Item: newItem });
    await docClient.send(command);
    return newItem;
};

const updateItem = async (id, itemData) => {
    let existing = await getItemById(id);
    if (!existing) return null;
    
    let updated = { ...existing, ...itemData, id };
    const command = new PutCommand({ TableName: TABLE_NAME, Item: updated });
    await docClient.send(command);
    return updated;
};

const deleteItem = async (id) => {
    let existing = await getItemById(id);
    if (!existing) return false;
    
    const command = new DeleteCommand({ TableName: TABLE_NAME, Key: { id } });
    await docClient.send(command);
    return true;
};

module.exports = {
    getAllItems,
    getItemById,
    createItem,
    updateItem,
    deleteItem
};
