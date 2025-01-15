import { MQStatus } from '@chimera-monorepo/utils';

import { Cache } from './cache';

export class MQCache extends Cache {
  private readonly prefix = 'messagequeue';

  /**
   * Gets the message status for the given message ID.
   * @param messageId - The ID of the message.
   * @returns Message status if exists, MQStatus.None if no entry was found.
   */
  public async getMessageStatus(messageId: string): Promise<MQStatus> {
    const res = await this.data.hget(`${this.prefix}:status`, messageId);
    return res && Object.values(MQStatus).includes(res as MQStatus) ? MQStatus[res as MQStatus] : MQStatus.None;
  }

  /**
   * Set the status of a given message ID.
   * @param messageId - The ID of the message we are setting the status of.
   * @param status - The status to set.
   */
  public async setMessageStatus(messageId: string, status: MQStatus): Promise<void> {
    if (status == MQStatus.Completed || status == MQStatus.None) {
      // Deletes the item in the cache for effective memory management.
      await this.data.hdel(`${this.prefix}:status`, messageId);
      return;
    }
    await this.data.hset(`${this.prefix}:status`, messageId, status.toString());
  }
}
