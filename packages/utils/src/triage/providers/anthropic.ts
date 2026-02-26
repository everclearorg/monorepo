import Anthropic from '@anthropic-ai/sdk';
import { parseTriageResult } from '../prompt';
import { TriageContext, TriageProvider, TriageResult } from '../types';
import { AnalyzeWithToolsArgs } from '../tools/types';

type AnthropicProviderConfig = {
  apiKey: string;
  baseUrl?: string;
};

async function withTimeout<T>(promise: Promise<T>, timeoutMs: number, label = 'Triage provider timeout'): Promise<T> {
  let timer: ReturnType<typeof setTimeout>;
  const timeoutPromise = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new Error(label)), timeoutMs);
  });
  try {
    return await Promise.race([promise, timeoutPromise]);
  } finally {
    clearTimeout(timer!);
  }
}

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
    const response = await withTimeout(
      this.client.messages.create({
        model,
        max_tokens: 800,
        temperature: 0.1,
        messages: [{ role: 'user', content: context.prompt }],
      }),
      timeoutMs,
    );

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
      const response = await withTimeout(
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
        args.timeoutMs,
      );

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

    const finalResponse = await withTimeout(
      this.client.messages.create({
        model: args.model,
        max_tokens: 1024,
        temperature: 0.1,
        messages,
      }),
      args.timeoutMs,
    );
    const textBlock = finalResponse.content.find((item) => item.type === 'text');
    return parseTriageResult(textBlock?.text ?? '{}');
  }
}
