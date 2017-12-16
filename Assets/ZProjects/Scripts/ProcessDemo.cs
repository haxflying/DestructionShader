using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ProcessDemo : MonoBehaviour {
    public Material mat;
    private void OnEnable()
    {
        StartCoroutine(process());
    }

    IEnumerator process()
    {
        float offset = 0.05f;
        float emission = 2;
        while (offset > 0)
        {
            offset -= 0.0001f;
            emission += 0.002f;
            mat.SetFloat("_Offset", offset);
            mat.SetFloat("_RustEmission", emission);
            yield return new WaitForEndOfFrame();
        }
        mat.SetFloat("_Offset", 0);
        float rust = 1f;
        while(rust > 0)
        {
            rust -= 0.05f;
            mat.SetFloat("_threshold", rust);
            yield return new WaitForSeconds(0.1f);
        }
    }

    private void OnDisable()
    {
        mat.SetFloat("_Offset", 0.05f);
        mat.SetFloat("_RustEmission", 2);
        mat.SetFloat("_threshold", 1);
    }
}
