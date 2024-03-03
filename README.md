# mlx-swift-chat

https://github.com/PreternaturalAI/mlx-swift-chat/assets/8635253/f20862f3-8cab-4803-ba6e-44108b075c9b


### Run LLM models locally with MLX!

> MLX is an efficient machine learning framework specifically designed for Apple silicon (i.e. your laptop!)
>
> – [@awnihannun](https://twitter.com/awnihannun/status/1732184443451019431)

This project is a fully native SwiftUI app that allows you to run local LLMs (e.g. Llama, Mistral) on Apple silicon in real-time using [MLX](https://github.com/ml-explore/mlx).

## Installation

1. Open the Xcode project
2. Go to **Signing & Capabilities**
3. Change the **Team** to your own team.
4. Set the destination to **My Mac**.
5. Click **Run**.

Support for iOS is coming next week.

## Usage

1. Click on **Manage Models** in the inspector view.
2. Download and install a model (we recommend starting with `Nous-Hermes-2-Mistral-7B-DPO-4bit-MLX`).
3. Go back to the inspector and select the downloaded model from the model picker.
4. Wait for the model to load, the status bar will flash "Ready" once it is loaded.
5. Click the run button.

<img width="300" alt="Screenshot 2024-03-02 at 6 44 24 PM" src="https://github.com/PreternaturalAI/mlx-swift-chat/assets/8635253/37dead8a-f943-4411-b50e-ab1731b46bfc">

## Roadmap

- [ ] Fix iOS builds
- [ ] Implement support for StableLM
- [ ] Implement basic support automatically adding model-specific chat templates to the prompt
- [ ] Add support for stop sequences
- [ ] Add more model suggestions
- [ ] ... (many, _many_ more items to be added soon pending sleep)

## Frequently Asked Questions

### What models are currently supported?

| Model   | Status                      |
| ------- | --------------------------- |
| Mistral | Supported                   |
| Llama   | Supported                   |
| Phi     | Supported                   |
| Gemma   | Supported (May have issues) |

### How do I add new models?

Models are downloaded from Hugging Face. To add a new model, visit the [MLX Community on HuggingFace](https://huggingface.co/mlx-community) and search for the model you want, then add it via **Manage Models** → **Add Model**

> [!IMPORTANT]
> Note that this project is still under active development and some models may require additional implementation to run correctly.

### Is this suitable for production?

No. This is not intended for deploying into production.

### What are the minimum hardware and software requirements?

- Apple Silicon Mac (M1/M2/M3) with macOS 14.0 or newer
- Any A-Series chip (iPad, iPhone) with iOS 17.2 or newer

### Does this collect any data?

No. Everything is run locally on device.

### What are the parameters?

- **Temperature**: Controls randomness. Lowering results in less random completions. As the temperature approaches zero, the model will become deterministic and repetitive.

- **Top K**: Sort predicted tokens by probability and discards those below the k-th one. A top-k value of 1 is equivalent to greedy search (select the most probable token).

- **Maximum length**: The maximum number of tokens to generate. Requests can use up to 2,048 tokens shared between prompt and completion. The exact limit varies by model. (One token is roughly 4 characters for normal English text)

## Acknowledgements

- [ml-explore/mlx-swift](https://github.com/ml-explore/mlx-swift)
- [huggingface/swift-chat](https://github.com/huggingface/swift-chat)

Special thanks to [Awni Hannun](https://github.com/awni) and [David Koski](https://github.com/davidkoski) for early testing and feedback

Much ❤️ to all the folks who made MLX (especially mlx-swift) possible!
