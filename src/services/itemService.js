let items = [
    { id: '1', name: 'MacBook Pro', price: 1999 },
    { id: '2', name: 'AirPods Max', price: 549 }
];

const getAllItems = () => {
    return items;
};

const getItemById = (id) => {
    return items.find(item => item.id === id);
};

const createItem = (itemData) => {
    const newItem = {
        id: String(Date.now()),
        ...itemData
    };
    items.push(newItem);
    return newItem;
};

const updateItem = (id, itemData) => {
    const index = items.findIndex(item => item.id === id);
    if (index === -1) return null;
    
    items[index] = { ...items[index], ...itemData, id };
    return items[index];
};

const deleteItem = (id) => {
    const index = items.findIndex(item => item.id === id);
    if (index === -1) return false;
    
    items.splice(index, 1);
    return true;
};

module.exports = {
    getAllItems,
    getItemById,
    createItem,
    updateItem,
    deleteItem
};
