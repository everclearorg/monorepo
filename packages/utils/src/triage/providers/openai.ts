import OpenAI from 'openai';
import { delay } from '../../helpers/axios';
import { parseTriageResult } from '../prompt';
import { TriageContext, TriageProvider, TriageResult } from '../types';
import { AnalyzeWithToolsArgs } from '../tools/types';

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

  public async analyzeWithTools(args: AnalyzeWithToolsArgs): Promise<TriageResult> {
    const messages: OpenAI.Chat.Completions.ChatCompletionMessageParam[] = [
      {
        role: 'system',
        content: 'Respond with valid JSON only.',
      },
      {
        role: 'user',
        content: args.context.prompt,
      },
    ];

    for (let round = 0; round < args.maxRounds; round++) {
      const response = await Promise.race([
        this.client.chat.completions.create({
          model: args.model,
          temperature: 0.1,
          messages,
          tools: args.tools.map((tool) => ({
            type: 'function' as const,
            function: {
              name: tool.name,
              description: tool.description,
              parameters: tool.parameters,
            },
          })),
        }),
        (async () => {
          await delay(args.timeoutMs);
          throw new Error('Triage provider timeout');
        })(),
      ]);

      const choice = response.choices?.[0];
      const toolCalls = choice?.message?.tool_calls ?? [];
      if (choice?.finish_reason !== 'tool_calls' || toolCalls.length === 0) {
        return parseTriageResult(choice?.message?.content ?? '{}');
      }

      const calls = toolCalls
        .filter((toolCall): toolCall is OpenAI.Chat.Completions.ChatCompletionMessageFunctionToolCall => {
          return toolCall.type === 'function';
        })
        .map((toolCall) => ({
          id: toolCall.id,
          name: toolCall.function.name,
          args: JSON.parse(toolCall.function.arguments || '{}') as Record<string, unknown>,
        }));
      const results = await args.executeToolCalls(calls);

      messages.push({
        role: 'assistant',
        content: choice.message.content ?? null,
        tool_calls: toolCalls,
      });
      for (const result of results) {
        messages.push({
          role: 'tool',
          tool_call_id: result.toolCallId,
          content: result.error ? JSON.stringify({ error: result.error }) : result.output || '{}',
        });
      }
    }

    return this.analyze(args.context, args.model, args.timeoutMs);
  }
}
