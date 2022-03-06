using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ForceRotation : MonoBehaviour
{
    public Quaternion rotation;
    void LateUpdate()
    {
        this.transform.rotation = rotation;
    }
}
