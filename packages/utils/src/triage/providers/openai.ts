import OpenAI from 'openai';
import { delay } from '../../helpers/axios';
import { parseTriageResult } from '../prompt';
import { TriageContext, TriageProvider, TriageResult } from '../types';

type OpenAIProviderConfig = {
  apiKey: string;
  baseUrl?: string;
};

export class OpenAITriageProvider implements TriageProvider {
  public readonly name = 'openai' as const;
  private readonly client: OpenAI;

  constructor(private readonly config: OpenAIProviderConfig) {
    this.client = new OpenAI({
      apiKey: config.apiKey,
      baseURL: config.baseUrl,
    });
  }

  public async analyze(context: TriageContext, model: string, timeoutMs: number): Promise<TriageResult> {
    const response = await Promise.race([
      this.client.chat.completions.create({
          model,
          temperature: 0.1,
          messages: [
            {
              role: 'system',
              content: 'Respond with valid JSON only.',
            },
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

    const content = response.choices?.[0]?.message?.content ?? '{}';
    return parseTriageResult(content);
  }
}
