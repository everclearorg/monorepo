import Anthropic from '@anthropic-ai/sdk';
import { delay } from '../../helpers/axios';
import { parseTriageResult } from '../prompt';
import { TriageContext, TriageProvider, TriageResult } from '../types';

type AnthropicProviderConfig = {
  apiKey: string;
  baseUrl?: string;
};

export class AnthropicTriageProvider implements TriageProvider {
  public readonly name = 'anthropic' as const;
  private readonly client: Anthropic;

  constructor(private readonly config: AnthropicProviderConfig) {
    this.client = new Anthropic({
      apiKey: config.apiKey,
      baseURL: config.baseUrl,
    });
  }

  public async analyze(context: TriageContext, model: string, timeoutMs: number): Promise<TriageResult> {
    const response = await Promise.race([
      this.client.messages.create({
          model,
          max_tokens: 800,
          temperature: 0.1,
          messages: [
            {
              role: 'user',
              content: context.prompt,
            },
          ],
        }),
      (async () => {
        await delay(timeoutMs);
        throw new Error('Triage provider timeout');
      })(),
    ]);

    const textBlock = response.content.find((item) => item.type === 'text');
    const text = textBlock?.text ?? '{}';
    return parseTriageResult(text);
  }
}
