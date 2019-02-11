# Abstract

물체에 anisotropic specular를 적용해보자

# Shader

```c
Shader "UnityShaderTutorial/basic_alpha_test" {
    Properties {
        _MainTex ("Base (RGB) Transparency (A)", 2D) = "" {}
	_Cutoff("Alpha cutoff", Range(0,1)) = 0.5
    }
    SubShader {
	Pass{
	    // Use the Cutoff parameter defined above to determine
	    // what to render.
	    AlphaTest Greater [_Cutoff]
	    SetTexture[_MainTex]{ combine texture }
	}
    }
}
```

# Description

# Prerequisites

```
비등방성(anisotropy)이란?

특정 방향에 따라 물체의 물리적 성질이 달라지는 것이 비등방성이다.
```