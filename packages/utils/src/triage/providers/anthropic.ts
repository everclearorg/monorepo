import Anthropic from '@anthropic-ai/sdk';
import { delay } from '../../helpers/axios';
import { parseTriageResult } from '../prompt';
import { TriageContext, TriageProvider, TriageResult } from '../types';
import { AnalyzeWithToolsArgs } from '../tools/types';

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

  public async analyzeWithTools(args: AnalyzeWithToolsArgs): Promise<TriageResult> {
    let messages: Anthropic.MessageParam[] = [
      {
        role: 'user',
        content: args.context.prompt,
      },
    ];

    for (let round = 0; round < args.maxRounds; round++) {
      const response = await Promise.race([
        this.client.messages.create({
          model: args.model,
          max_tokens: 1024,
          temperature: 0.1,
          messages,
          tools: args.tools.map((tool) => ({
            name: tool.name,
            description: tool.description,
            input_schema: tool.parameters as Anthropic.Tool.InputSchema,
          })),
        }),
        (async () => {
          await delay(args.timeoutMs);
          throw new Error('Triage provider timeout');
        })(),
      ]);

      const toolUseBlocks = response.content.filter((item) => item.type === 'tool_use');
      if (toolUseBlocks.length === 0) {
        const textBlock = response.content.find((item) => item.type === 'text');
        return parseTriageResult(textBlock?.text ?? '{}');
      }

      const calls = toolUseBlocks.map((block) => ({
        id: block.id,
        name: block.name,
        args: (block.input ?? {}) as Record<string, unknown>,
      }));
      const results = await args.executeToolCalls(calls);

      const toolResultContent = results.map((result) => ({
        type: 'tool_result' as const,
        tool_use_id: result.toolCallId,
        content: result.error ? JSON.stringify({ error: result.error }) : result.output || '{}',
        is_error: Boolean(result.error),
      }));

      messages = [
        ...messages,
        {
          role: 'assistant',
          content: response.content,
        },
        {
          role: 'user',
          content: toolResultContent,
        },
      ];
    }

    return this.analyze(args.context, args.model, args.timeoutMs);
  }
}
