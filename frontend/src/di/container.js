import { createContainer, asFunction } from './miniContainer.js';
import { createApiClient } from '../utils/api.js';
import { createStorage } from '../utils/storage.js';
import { createSmsRepo } from '../repo/SmsRepo.js';
import { createTimeRepo } from '../repo/TimeRepo.js';
import { createSmsInteractor } from '../interactor/SmsInteractor.js';
import { createTimeInteractor } from '../interactor/TimeInteractor.js';

export function createAppContainer() {
  const container = createContainer();

  container.register({
    api: asFunction(createApiClient),
    storage: asFunction(createStorage),
    smsRepo: asFunction(createSmsRepo),
    timeRepo: asFunction(createTimeRepo),
    smsInteractor: asFunction(createSmsInteractor),
    timeInteractor: asFunction(createTimeInteractor),
  });

  return container;
}
