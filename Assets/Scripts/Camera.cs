using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Camera : MonoBehaviour
{
    public GameObject target;
    Vector3 offset;
    public float posLerpFactor;
    public float rotLerpFactor;

    private Vector3 camVel = Vector3.zero;
    // Start is called before the first frame update
    void Start()
    {
        offset = transform.position-target.transform.position;
    }

    [ExecuteInEditMode]
    // Update is called once per frame
    void LateUpdate()
    {
        transform.position = Vector3.SmoothDamp(transform.position, target.transform.position + offset, ref camVel, posLerpFactor);

        Vector3 relativePos = target.transform.position - transform.position;
        transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(relativePos, Vector3.up),rotLerpFactor);
    }
}

