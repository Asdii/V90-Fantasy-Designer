import { parseWorkspaceSnapshot, serializeWorkspaceSnapshot, type WorkspaceSnapshot } from './WorkspaceSnapshot';

const DATABASE_NAME = 'v90-fantasy-designer';
const STORE_NAME = 'workspace';
const CURRENT_KEY = 'current';

export async function saveWorkspaceCache(snapshot: WorkspaceSnapshot): Promise<void> {
  const database = await openDatabase();
  await requestToPromise(database.transaction(STORE_NAME, 'readwrite').objectStore(STORE_NAME).put(
    serializeWorkspaceSnapshot(snapshot),
    CURRENT_KEY,
  ));
  database.close();
}

export async function loadWorkspaceCache(): Promise<WorkspaceSnapshot | undefined> {
  const database = await openDatabase();
  const raw = await requestToPromise<string | undefined>(database.transaction(STORE_NAME, 'readonly').objectStore(STORE_NAME).get(CURRENT_KEY));
  database.close();
  return raw ? parseWorkspaceSnapshot(raw) : undefined;
}

function openDatabase(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE_NAME, 1);
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains(STORE_NAME)) request.result.createObjectStore(STORE_NAME);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error('Could not open project cache.'));
  });
}

function requestToPromise<T>(request: IDBRequest<T>): Promise<T> {
  return new Promise((resolve, reject) => {
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error('Project cache operation failed.'));
  });
}
