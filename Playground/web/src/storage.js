export function tx(db, stores, mode, work) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(stores, mode);
    let result;
    transaction.oncomplete = () => resolve(result);
    transaction.onerror = () => reject(transaction.error);
    transaction.onabort = () =>
      reject(transaction.error || new Error("Transaction aborted"));
    try {
      result = work(transaction);
    } catch (error) {
      transaction.abort();
      reject(error);
    }
  });
}
export function getAll(db, store) {
  return new Promise((resolve, reject) => {
    const transaction = db.transaction(store, "readonly");
    const request = transaction.objectStore(store).getAll();
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}
export function openDb() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open("LuaTinkerPlayground", 1);
    request.onupgradeneeded = () => {
      const db = request.result;
      db.createObjectStore("files", { keyPath: "path" });
      db.createObjectStore("meta", { keyPath: "key" });
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
    request.onblocked = () => reject(new Error("Database is blocked"));
  });
}

export function setMeta(store, key, value) {
  store.put({ key, value });
}
