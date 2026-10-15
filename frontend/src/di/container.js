import { createContainer, asFunction } from './miniContainer.js';
import { createApiClient } from '../utils/api.js';
import { createStorage } from '../utils/storage.js';
import { createLogger } from '../utils/logger.js';
import { createSmsRepo } from '../repo/SmsRepo.js';
import { createTimeRepo } from '../repo/TimeRepo.js';
import { createLogsRepo } from '../repo/LogsRepo.js';
import { createIpRepo } from '../repo/IpRepo.js';
import { createSmsInteractor } from '../interactor/SmsInteractor.js';
import { createTimeInteractor } from '../interactor/TimeInteractor.js';
import { createLogsInteractor } from '../interactor/LogsInteractor.js';
import { createIpInteractor } from '../interactor/IpInteractor.js';

export function createAppContainer() {
  const container = createContainer();

  container.register({
    api: asFunction(createApiClient),
    storage: asFunction(createStorage),
    logger: asFunction(createLogger),
    smsRepo: asFunction(createSmsRepo),
    timeRepo: asFunction(createTimeRepo),
    logsRepo: asFunction(createLogsRepo),
    ipRepo: asFunction(createIpRepo),
    smsInteractor: asFunction(createSmsInteractor),
    timeInteractor: asFunction(createTimeInteractor),
    logsInteractor: asFunction(createLogsInteractor),
    ipInteractor: asFunction(createIpInteractor),
  });

  return container;
}
