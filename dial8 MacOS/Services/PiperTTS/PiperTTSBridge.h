#ifndef PiperTTSBridge_h
#define PiperTTSBridge_h

#ifdef __cplusplus
extern "C" {
#endif

// Helper functions for creating configs from Swift
void* createPiperTtsConfig(const char* model_path, const char* tokens_path, const char* data_dir);
void freePiperTtsConfig(void* config);

#ifdef __cplusplus
}
#endif

#endif /* PiperTTSBridge_h */