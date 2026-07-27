import {
  createUnsubscribeToken,
  hashUnsubscribeToken,
} from "./token";

export type UnsubscribeRepository = {
  setTokenHash(entryId: string, tokenHash: string): Promise<void>;
  unsubscribeByTokenHash(tokenHash: string): Promise<boolean>;
};

export function createUnsubscribeService({
  repository,
  tokenSecret,
}: {
  repository: UnsubscribeRepository;
  tokenSecret: string;
}) {
  return {
    async issue(entryId: string) {
      const token = createUnsubscribeToken();
      await repository.setTokenHash(
        entryId,
        hashUnsubscribeToken(token, tokenSecret),
      );
      return token;
    },

    async unsubscribe(token: string) {
      return repository.unsubscribeByTokenHash(
        hashUnsubscribeToken(token, tokenSecret),
      );
    },
  };
}
