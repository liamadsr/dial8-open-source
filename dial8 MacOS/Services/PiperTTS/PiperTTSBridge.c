#include <stdlib.h>
#include <string.h>

// Define the config structures exactly as in the C API
typedef struct SherpaOnnxOfflineTtsVitsModelConfig {
    const char *model;
    const char *lexicon;
    const char *tokens;
    const char *data_dir;
    float noise_scale;
    float noise_scale_w;
    float length_scale;
    const char *dict_dir;
} SherpaOnnxOfflineTtsVitsModelConfig;

typedef struct SherpaOnnxOfflineTtsMatchaModelConfig {
    const char *acoustic_model;
    const char *vocoder;
    const char *lexicon;
    const char *tokens;
    const char *data_dir;
    float noise_scale;
    float length_scale;
} SherpaOnnxOfflineTtsMatchaModelConfig;

typedef struct SherpaOnnxOfflineTtsKokoroModelConfig {
    const char *model;
    const char *voices;
    const char *vocode;
    int32_t num_tasks;
} SherpaOnnxOfflineTtsKokoroModelConfig;

typedef struct SherpaOnnxOfflineTtsKittenModelConfig {
    const char *encoder;
    const char *embedding;
    const char *t2s;
    const char *vocoder;
    const char *lexicon;
    const char *tokens;
    const char *data_dir;
    float length_scale;
} SherpaOnnxOfflineTtsKittenModelConfig;

typedef struct SherpaOnnxOfflineTtsModelConfig {
    SherpaOnnxOfflineTtsVitsModelConfig vits;
    int32_t num_threads;
    int32_t debug;
    const char *provider;
    SherpaOnnxOfflineTtsMatchaModelConfig matcha;
    SherpaOnnxOfflineTtsKokoroModelConfig kokoro;
    SherpaOnnxOfflineTtsKittenModelConfig kitten;
} SherpaOnnxOfflineTtsModelConfig;

typedef struct SherpaOnnxOfflineTtsConfig {
    SherpaOnnxOfflineTtsModelConfig model;
    const char *rule_fsts;
    int32_t max_num_sentences;
    const char *rule_fars;
    float silence_scale;
} SherpaOnnxOfflineTtsConfig;

// Helper function to create a config safely
void* createPiperTtsConfig(const char* model_path, const char* tokens_path, const char* data_dir) {
    SherpaOnnxOfflineTtsConfig* config = (SherpaOnnxOfflineTtsConfig*)calloc(1, sizeof(SherpaOnnxOfflineTtsConfig));
    
    // Set VITS model config
    config->model.vits.model = model_path;
    config->model.vits.tokens = tokens_path;
    config->model.vits.data_dir = data_dir;
    config->model.vits.lexicon = NULL;
    config->model.vits.noise_scale = 0.667f;
    config->model.vits.noise_scale_w = 0.8f;
    config->model.vits.length_scale = 1.0f;
    config->model.vits.dict_dir = NULL;
    
    // Set other model configs to NULL/0
    memset(&config->model.matcha, 0, sizeof(config->model.matcha));
    memset(&config->model.kokoro, 0, sizeof(config->model.kokoro));
    memset(&config->model.kitten, 0, sizeof(config->model.kitten));
    
    // Set general model config
    config->model.num_threads = 2;
    config->model.debug = 0;
    config->model.provider = "cpu";
    
    // Set TTS config
    config->rule_fsts = NULL;
    config->rule_fars = NULL;
    config->max_num_sentences = 2;
    config->silence_scale = 0.3f;
    
    return config;
}

void freePiperTtsConfig(void* config) {
    if (config) {
        free(config);
    }
}