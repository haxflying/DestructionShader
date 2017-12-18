using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ProcessDemoVoro : MonoBehaviour {

    Material mat;
    private void OnEnable()
    {
        mat = GetComponent<Renderer>().material;
        StartCoroutine(process());
	}
	
	IEnumerator process()
    {
        float scale = 0;
        while(scale < 0.6f)
        {
            scale += 0.01f;
            mat.SetFloat("_DestrucScale", scale);
            print(scale);
            yield return new WaitForSeconds(0.05f);
        }
    }

    private void OnDisable()
    {
        mat.SetFloat("_DestrucScale", 0);
    }
}
