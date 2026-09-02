import Foundation

/// The bundled brand mark for a provider, by asset name, or nil for a generic symbol.
public enum ProviderIcon {
    public static func name(for kind: ProviderKind) -> String? { kind.icon }

    public static func name(for url: URL) -> String? {
        let host = url.host()?.lowercased() ?? ""
        if host == "localhost" || host == "127.0.0.1" || host.hasSuffix(".local") {
            switch url.port {
            case 11434: return "ollama"
            case 1234: return "lmstudio"
            case 8000: return "vllm"
            default: break
            }
        }
        if host.contains("ollama") { return "ollama" }
        if host.contains("github") { return "github" }
        return hosts.first { host.hasSuffix($0.suffix) }?.icon
    }

    private static let hosts: [(suffix: String, icon: String)] = [
        ("models.inference.ai.azure.com", "github"), ("openrouter.ai", "openrouter"), ("groq.com", "groq"), ("googleapis.com", "gemini"),
        ("mistral.ai", "mistral"), ("x.ai", "xai"), ("deepseek.com", "deepseek"),
        ("together.xyz", "together"), ("fireworks.ai", "fireworks"), ("perplexity.ai", "perplexity"),
        ("huggingface.co", "huggingface"), ("cohere.com", "cohere"), ("cohere.ai", "cohere"),
        ("azure.com", "azure"), ("cerebras.ai", "cerebras"), ("sambanova.ai", "sambanova"),
        ("moonshot.cn", "moonshot"), ("moonshot.ai", "moonshot"), ("aliyuncs.com", "qwen"),
        ("bigmodel.cn", "zhipu"), ("z.ai", "zhipu"), ("minimax.chat", "minimax"), ("minimaxi.com", "minimax"),
        ("novita.ai", "novita"), ("hyperbolic.xyz", "hyperbolic"), ("nvidia.com", "nvidia"),
        ("siliconflow.cn", "siliconcloud"), ("siliconflow.com", "siliconcloud"), ("deepinfra.com", "deepinfra"),
        ("cloudflare.com", "cloudflare"), ("ai21.com", "ai21"), ("stepfun.com", "stepfun"),
        ("volces.com", "volcengine"), ("lingyiwanwu.com", "yi"), ("baichuan-ai.com", "baichuan"),
        ("302.ai", "ai302"), ("ppinfra.com", "ppio"), ("kluster.ai", "kluster"), ("friendli.ai", "friendli"),
        ("modelscope.cn", "modelscope"), ("upstage.ai", "upstage"), ("poe.com", "poe"),
        ("vercel.sh", "vercel"), ("replicate.com", "replicate"), ("openai.com", "openai"),
        ("anthropic.com", "claude"),
    ]
}
