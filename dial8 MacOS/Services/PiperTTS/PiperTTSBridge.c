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
    float silence_scale;  // Required for v1.12.9
} SherpaOnnxOfflineTtsConfig;

// Helper function to create a config safely
void* createPiperTtsConfig(const char* model_path, const char* tokens_path, const char* data_dir) {
    // Use calloc to ensure all memory is zeroed
    SherpaOnnxOfflineTtsConfig* config = (SherpaOnnxOfflineTtsConfig*)calloc(1, sizeof(SherpaOnnxOfflineTtsConfig));
    
    if (!config) {
        return NULL;
    }
    
    // Initialize everything to zero first
    memset(config, 0, sizeof(SherpaOnnxOfflineTtsConfig));
    
    // Set VITS model config with proper values
    config->model.vits.model = model_path;
    config->model.vits.tokens = tokens_path;
    config->model.vits.data_dir = data_dir;
    config->model.vits.lexicon = "";  // Empty string instead of NULL
    config->model.vits.noise_scale = 0.667f;
    config->model.vits.noise_scale_w = 0.8f;
    config->model.vits.length_scale = 1.0f;
    config->model.vits.dict_dir = "";  // Empty string instead of NULL
    
    // Set general model config
    config->model.num_threads = 8;  // Use more threads for faster generation
    config->model.debug = 0;
    config->model.provider = "cpu";
    
    // Set TTS config with proper defaults
    config->rule_fsts = "";  // Empty string instead of NULL
    config->rule_fars = "";  // Empty string instead of NULL
    config->max_num_sentences = 2;
    config->silence_scale = 0.3f;  // Default silence scale for v1.12.9
    
    return config;
}

void freePiperTtsConfig(void* config) {
    if (config) {
        free(config);
    }
}