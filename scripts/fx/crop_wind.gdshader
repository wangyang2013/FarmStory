shader_type canvas_item;

// 作物随风摆动：根部锁定，越靠上摆动越大。
// 每块农田通过 phase 参数得到不同相位，禁止整屏同步。
uniform float base_y = 26.0;
uniform float height = 18.0;
uniform float phase = 0.0;
uniform float strength = 0.75;

void vertex() {
	float h = clamp((base_y - VERTEX.y) / height, 0.0, 1.0);
	float weight = h * h;
	VERTEX.x += sin(TIME * 1.8 + phase) * strength * weight;
}
